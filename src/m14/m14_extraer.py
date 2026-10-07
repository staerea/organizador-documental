#!/usr/bin/env python3
"""M14 - Indice de metadatos y entidades (organizador-documental v1.11).

Extraccion por REGLAS (sin IA) de entidades de documentos ya clasificados. Se ejecuta en el contenedor de la
tarea horaria de Claude sobre lotes de archivos copiados desde la raiz documental.

Uso:
  m14_extraer.py --lote lote.csv --indice indice_entidades.csv --estado m14_estado.csv [--ocr]

  lote.csv (;, UTF-8): SHA256;RutaRelativa;RutaLocal
  indice_entidades.csv (salida, se anaden filas): SHA256;RutaRelativa;Campo;Valor;Pagina;Confianza;Version
  m14_estado.csv (salida, se anaden filas):        SHA256;RutaRelativa;Fecha;Resultado;Entidades;Version

Privacidad (reglas del skill):
  - Nunca se extraen DNI/NIE ni IBAN, tarjetas, telefonos, correos ni nombres de personas fisicas.
  - Solo CIF de personas juridicas (letra inicial de sociedad/entidad, con digito de control valido).
  - 09_PERSONAL_SENSIBLE: solo TIPO_DOCUMENTO y FECHA_DOCUMENTO.
  - No se guardan importes.
Resultado por archivo: OK / SIN_ENTIDADES (candidato a lectura por Claude) / SIN_TEXTO (escaneo: OCR o revision) / ERROR.
"""
import argparse, csv, datetime as dt, os, re, subprocess, sys, unicodedata, zipfile
from collections import OrderedDict

VERSION = '1.11'
MESES = {m: i for i, m in enumerate(['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
                                     'septiembre', 'octubre', 'noviembre', 'diciembre'], 1)}
MESES['setiembre'] = 9
ORGANISMOS_FIJOS = OrderedDict([
    (r'\bAESA\b|Agencia Estatal de Seguridad A[ée]rea', 'AESA'),
    (r'\bAEAT\b|Agencia (Estatal de Administraci[óo]n )?Tributaria', 'AEAT'),
    (r'\bTGSS\b|Tesorer[íi]a General de la Seguridad Social', 'TGSS'),
    (r'\bINSS\b|Instituto Nacional de la Seguridad Social', 'INSS'),
    (r'\bSEPE\b|Servicio P[úu]blico de Empleo Estatal', 'SEPE'),
    (r'\bBOE\b|Bolet[íi]n Oficial del Estado', 'BOE'),
    (r'\bBORM\b|Bolet[íi]n Oficial de la Regi[óo]n de Murcia', 'BORM'),
    (r'\bDOE\b|Diario Oficial de Extremadura', 'DOE'),
    (r'\bCARM\b|Comunidad Aut[óo]noma de la Regi[óo]n de Murcia', 'CARM'),
    (r'Junta de Extremadura', 'Junta de Extremadura'),
    (r'Junta de Andaluc[íi]a', 'Junta de Andalucía'),
    (r'Generalitat Valenciana', 'Generalitat Valenciana'),
    (r'\bCHS\b|Confederaci[óo]n Hidrogr[áa]fica del Segura', 'CHS'),
    (r'Confederaci[óo]n Hidrogr[áa]fica del Guadiana', 'CH Guadiana'),
    (r'\bENAIRE\b', 'ENAIRE'), (r'\bEASA\b|European Union Aviation Safety Agency', 'EASA'),
    (r'\bCDTI\b', 'CDTI'), (r'\bCSIC\b|Consejo Superior de Investigaciones Cient[íi]ficas', 'CSIC'),
    (r'\bMAPA\b|Ministerio de Agricultura, Pesca y Alimentaci[óo]n', 'MAPA'),
    (r'\bDEHU\b|Direcci[óo]n Electr[óo]nica Habilitada [úu]nica', 'DEHú'),
    (r'\bCopernicus\b', 'Copernicus'), (r'\bESA\b|European Space Agency|Agencia Espacial Europea', 'ESA'),
    (r'\bRegistro Mercantil\b', 'Registro Mercantil'), (r'\bDGT\b|Direcci[óo]n General de Tr[áa]fico', 'DGT'),
    (r'\bINE\b|Instituto Nacional de Estad[íi]stica', 'INE'), (r'\bIGN\b|Instituto Geogr[áa]fico Nacional', 'IGN'),
    (r'\bCNIG\b', 'CNIG'), (r'\bAEPD\b|Agencia Espa[ñn]ola de Protecci[óo]n de Datos', 'AEPD'),
])
RX_ORG_VAR = re.compile(r'\b((?:Excmo\.?\s+)?Ayuntamiento|Universidad(?: Polit[ée]cnica| Aut[óo]noma| Nacional)?|Ministerio|Consejer[íi]a|Diputaci[óo]n(?: Provincial)?|Cabildo|Mancomunidad|Comunidad de Regantes)[ \t]+de(?:l| la| los| las)?[ \t]+((?:[A-ZÁÉÍÓÚÑ][\wáéíóúñü\-]+)(?:[ \t]+(?:(?:y|de|del|la|las|los|e)[ \t]+)?[A-ZÁÉÍÓÚÑ][\wáéíóúñü\-]+){0,5})')
RX_CIF = re.compile(r'\b([ABCDEFGHJNPQRSUVW])[-\s.]?(\d{7})[-\s.]?([0-9A-J])\b')
RX_FECHA_NUM = re.compile(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b')
RX_FECHA_ISO = re.compile(r'\b(\d{4})-(\d{2})-(\d{2})\b')
RX_FECHA_TXT = re.compile(r'\b(\d{1,2})\s+de\s+(' + '|'.join(MESES) + r')\s+(?:de|del)\s+(\d{4})\b', re.I)
RX_EXPTE = re.compile(r'\b(?:expediente|exp(?:te)?\.)\s*(?:n[º°o.]*|n[úu]m(?:ero)?\.?)?\s*[:#]?\s*([A-Z0-9][A-Z0-9/\-_.]{3,30}[A-Z0-9])', re.I)
RX_FACT = re.compile(r'\b(?:factura|fra\.)\s*(?:n[º°o.]*|n[úu]m(?:ero)?\.?)\s*[:#]?\s*([A-Z0-9][A-Z0-9/\-_.]{2,20}[A-Z0-9])', re.I)
RX_CATASTRO = re.compile(r'\b(\d{7}[A-Z]{2}\d{4}[A-Z]\d{4}[A-Z]{2}|\d{5}[A-Z]\d{8}\d{4}[A-Z]{2})\b')
RX_EMPRESA = re.compile(r'\b((?:[A-ZÁÉÍÓÚÑ][\wÁÉÍÓÚÑáéíóúñ&\-]+\s+){0,4}[A-ZÁÉÍÓÚÑ][\wÁÉÍÓÚÑáéíóúñ&\-]+),?\s+(S\.?\s?L\.?(?:\s?U\.?)?|S\.?\s?A\.?(?:\s?U\.?)?|S\.?\s?Coop\.?)(?=[\s,.;)]|$)')
TIPOS = {'.pdf': 'PDF', '.docx': 'DOCX', '.doc': 'DOC', '.xlsx': 'XLSX', '.xls': 'XLS', '.pptx': 'PPTX', '.odt': 'ODT',
         '.txt': 'TXT', '.md': 'MD', '.csv': 'CSV', '.html': 'HTML', '.htm': 'HTML', '.rtf': 'RTF'}
LETRAS_CIF = 'JABCDEFGHI'


def cif_valido(l, d, c):
    s_par = sum(int(d[i]) for i in (1, 3, 5))
    s_imp = sum(sum(divmod(int(d[i]) * 2, 10)) for i in (0, 2, 4, 6))
    u = (10 - (s_par + s_imp) % 10) % 10
    if l in 'PQRSNW':
        return c == LETRAS_CIF[u]
    if l in 'ABEH':
        return c == str(u)
    return c in (str(u), LETRAS_CIF[u])


def texto_paginas(ruta, ext, ocr=False, max_pag=6):
    """Devuelve lista de (pagina, texto)."""
    if ext == '.pdf':
        try:
            out = subprocess.run(['pdftotext', '-layout', '-l', str(max_pag), '-enc', 'UTF-8', ruta, '-'],
                                 capture_output=True, timeout=120).stdout.decode('utf-8', 'replace')
        except Exception:
            out = ''
        pags = out.split('\f')
        if ocr and len(re.sub(r'\s', '', out)) < 40:
            pags = ocr_pdf(ruta, max_pag)
        return [(i + 1, p) for i, p in enumerate(pags) if p.strip()]
    if ext in ('.docx', '.xlsx', '.pptx', '.odt'):
        try:
            with zipfile.ZipFile(ruta) as z:
                nombres = {'.docx': ['word/document.xml'], '.odt': ['content.xml'], '.xlsx': ['xl/sharedStrings.xml'],
                           '.pptx': sorted([n for n in z.namelist() if re.match(r'ppt/slides/slide\d+\.xml$', n)],
                                           key=lambda n: int(re.findall(r'\d+', n)[-1]))[:max_pag * 2]}[ext]
                res = []
                for i, n in enumerate(nombres):
                    if n in z.namelist():
                        xml = z.read(n).decode('utf-8', 'replace')
                        xml = re.sub(r'</w:p>|</a:p>|</text:p>|</si>', '\n', xml)
                        res.append((i + 1, re.sub(r'<[^>]+>', ' ', xml)))
                return res
        except Exception:
            return []
    if ext in ('.txt', '.md', '.csv', '.html', '.htm'):
        try:
            with open(ruta, 'rb') as f:
                b = f.read(400_000)
            t = b.decode('utf-8', 'replace')
            if ext in ('.html', '.htm'):
                t = re.sub(r'<[^>]+>', ' ', t)
            return [(1, t)]
        except Exception:
            return []
    return []


def ocr_pdf(ruta, max_pag):
    import tempfile, glob
    with tempfile.TemporaryDirectory() as d:
        try:
            subprocess.run(['pdftoppm', '-r', '200', '-l', str(max_pag), '-png', ruta, os.path.join(d, 'p')], timeout=300, check=False)
        except Exception:
            return []
        pags = []
        for img in sorted(glob.glob(os.path.join(d, 'p*.png'))):
            try:
                t = subprocess.run(['tesseract', img, '-', '-l', 'spa+eng'], capture_output=True, timeout=180).stdout.decode('utf-8', 'replace')
            except Exception:
                t = ''
            pags.append(t)
        return pags


def norm_espacios(s):
    return re.sub(r'\s+', ' ', s).strip()


def fecha_ok(a, m, d):
    try:
        f = dt.date(int(a), int(m), int(d))
        return f if 1990 <= f.year <= dt.date.today().year + 6 else None
    except ValueError:
        return None


def extraer(rel, paginas):
    sensible = rel.replace('/', '\\').upper().startswith('09_PERSONAL_SENSIBLE')
    ent = OrderedDict()   # (campo, valor) -> (pagina, confianza)

    def add(campo, valor, pag, conf):
        valor = norm_espacios(str(valor))[:120]
        if valor and (campo, valor) not in ent:
            ent[(campo, valor)] = (pag, conf)

    partes = rel.replace('/', '\\').split('\\')
    if len(partes) > 2 and partes[0].startswith('01_'):
        add('PROYECTO', partes[1], '', '1.0')
    ext = os.path.splitext(rel)[1].lower()
    add('TIPO_DOCUMENTO', TIPOS.get(ext, ext.lstrip('.').upper() or '?'), '', '1.0')
    fechas = []
    for pag, t in paginas:
        for m in RX_FECHA_NUM.finditer(t):
            f = fecha_ok(m.group(3), m.group(2), m.group(1))
            if f: fechas.append((m.start() + (pag - 1) * 10**6, f, pag))
        for m in RX_FECHA_ISO.finditer(t):
            f = fecha_ok(m.group(1), m.group(2), m.group(3))
            if f: fechas.append((m.start() + (pag - 1) * 10**6, f, pag))
        for m in RX_FECHA_TXT.finditer(t):
            f = fecha_ok(m.group(3), MESES[m.group(2).lower()], m.group(1))
            if f: fechas.append((m.start() + (pag - 1) * 10**6, f, pag))
    if fechas:
        fechas.sort(key=lambda x: x[0])
        add('FECHA_DOCUMENTO', fechas[0][1].isoformat(), fechas[0][2], '0.5')
    if sensible:
        return ent
    for _, f, pag in fechas[:12]:
        add('FECHA', f.isoformat(), pag, '0.6')
    for pag, t in paginas:
        for rx, nombre in ORGANISMOS_FIJOS.items():
            if re.search(rx, t):
                add('ORGANISMO', nombre, pag, '0.8')
        for m in RX_ORG_VAR.finditer(t):
            tipo = re.sub(r'^Excmo\.?\s+', '', m.group(1))
            add('ORGANISMO', f'{tipo} de {m.group(2)}', pag, '0.7')
        for m in RX_CIF.finditer(t.upper()):
            if cif_valido(m.group(1), m.group(2), m.group(3)):
                add('CIF_EMPRESA', m.group(1) + m.group(2) + m.group(3), pag, '0.9')
        for m in RX_EMPRESA.finditer(t):
            nombre = norm_espacios(m.group(1))
            if len(nombre) >= 3 and not re.match(r'^(La|El|Los|Las|De|Del|Y|En|Por)$', nombre):
                forma = re.sub(r'[\s.]', '', m.group(2)).upper()
                add('EMPRESA', nombre + ' ' + forma, pag, '0.6')
        for m in RX_EXPTE.finditer(t):
            v = m.group(1).strip('.-_/')
            if re.search(r'\d', v) and len(v) >= 4:
                add('EXPEDIENTE', v, pag, '0.7')
        for m in RX_FACT.finditer(t):
            v = m.group(1).strip('.-_/')
            if re.search(r'\d', v):
                add('NUM_FACTURA', v, pag, '0.7')
        for m in RX_CATASTRO.finditer(t.upper()):
            add('REF_CATASTRAL', m.group(1), pag, '0.7')
    return ent


def anexar(ruta, cab, filas):
    nuevo = not os.path.exists(ruta)
    with open(ruta, 'a', newline='', encoding='utf-8-sig' if nuevo else 'utf-8') as f:
        w = csv.writer(f, delimiter=';', quoting=csv.QUOTE_ALL, lineterminator='\r\n')
        if nuevo:
            w.writerow(cab)
        w.writerows(filas)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lote', required=True); ap.add_argument('--indice', required=True); ap.add_argument('--estado', required=True)
    ap.add_argument('--ocr', action='store_true')
    a = ap.parse_args()
    with open(a.lote, encoding='utf-8-sig') as f:
        lote = list(csv.DictReader(f, delimiter=';'))
    hoy = dt.datetime.now().strftime('%Y-%m-%dT%H:%M:%S'); resumen = {}
    for r in lote:
        sha, rel, loc = r['SHA256'], r['RutaRelativa'], r['RutaLocal']
        ext = os.path.splitext(rel)[1].lower()
        try:
            pags = texto_paginas(loc, ext, a.ocr)
            sin_texto = len(re.sub(r'\s', '', ''.join(t for _, t in pags))) < 40
            ent = extraer(rel, pags)
            utiles = [k for k in ent if k[0] not in ('TIPO_DOCUMENTO', 'PROYECTO')]
            res = 'SIN_TEXTO' if sin_texto and ext in TIPOS else ('OK' if utiles else 'SIN_ENTIDADES')
            anexar(a.indice, ['SHA256', 'RutaRelativa', 'Campo', 'Valor', 'Pagina', 'Confianza', 'Version'],
                   [[sha, rel, c, v, p, conf, VERSION] for (c, v), (p, conf) in ent.items()])
        except Exception as e:
            res, ent = 'ERROR: ' + str(e)[:150], {}
        anexar(a.estado, ['SHA256', 'RutaRelativa', 'Fecha', 'Resultado', 'Entidades', 'Version'], [[sha, rel, hoy, res, len(ent), VERSION]])
        k = res.split(':')[0]; resumen[k] = resumen.get(k, 0) + 1
    print(';'.join(f'{k}={v}' for k, v in sorted(resumen.items())))


if __name__ == '__main__':
    main()
