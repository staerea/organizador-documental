#!/usr/bin/env python3
"""M12 - Casi duplicados (organizador-documental v1.11.4). SOLO LECTURA: no mueve ni borra nada.

Subcomandos:
  candidatos --manifiesto M [--desde AAAA-MM-DD] [--salida candidatos.csv]
      Grupos de archivos vigentes con el mismo nombre base (sin _vN, (n), -n, _vNN) en la misma carpeta y con la
      misma extension, en los que al menos un miembro se clasifico desde la fecha indicada (sin fecha: todos).
  comparar --lote lote.csv --informe casi_duplicados.csv
      lote.csv: Grupo;RutaRelativa;RutaLocal (copias locales traidas con device_stage_files). Compara cada grupo
      (SHA-256, texto extraido y paginas, imagen perceptual, lista de un ZIP) y anade filas al informe.
  par --a RUTA --b RUTA
      Compara dos archivos locales e imprime JSON {clase, similitud, paginas}. Se usa al clasificar, antes de
      numerar un archivo con _vN: si la clase es IDENTICO o MISMO_CONTENIDO, no se numera (va al informe).
Clases: IDENTICO (SHA igual), MISMO_CONTENIDO (texto >= 0.98 y mismas paginas; imagen >= 0.97),
        CASI_IGUAL (>= 0.90), VERSION_DISTINTA (< 0.90), SIN_DATOS (no comparable: sin texto ni imagen).
"""
import argparse, csv, collections, difflib, hashlib, json, os, re, subprocess, sys, zipfile

SUF = re.compile(r'(_v\d+|\s*\(\d+\)|-\d|__COPIA_\d+| - copia| copy)$', re.I)
NATIVOS = {'gdoc','gsheet','gslides','gdraw','gform','gmap','gsite','gjam','gtable','gscript','glink','gnote'}
VIGENTES = {'HEREDADO','MOVIDO','MOVIDO_HASH_NO_VERIFICADO','MOVIDO_HUELLA_NO_VERIFICADA'}
IMG = {'png','jpg','jpeg','webp','bmp','tif','tiff','gif'}

def clave(ruta):
    d, _, n = ruta.replace('/', '\\').rpartition('\\'); s, dot, e = n.rpartition('.')
    if not dot: s, e = n, ''
    return d.lower(), SUF.sub('', s).lower(), e.lower()

def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''): h.update(b)
    return h.hexdigest()

def texto(p):
    e = p.rsplit('.', 1)[-1].lower()
    try:
        if e == 'pdf':
            t = subprocess.run(['pdftotext', '-q', p, '-'], capture_output=True, timeout=180).stdout.decode('utf-8', 'ignore')
        elif e in ('docx', 'pptx', 'xlsx'):
            z = zipfile.ZipFile(p)
            t = ' '.join(re.sub(rb'<[^>]+>', b' ', z.read(n)).decode('utf-8', 'ignore') for n in z.namelist()
                         if n.endswith('.xml') and ('word/document' in n or 'ppt/slides/slide' in n or 'sharedStrings' in n or 'worksheets/sheet' in n))
        elif e == 'zip':
            t = '\n'.join(sorted(f'{i.filename} {i.file_size} {i.CRC:08x}' for i in zipfile.ZipFile(p).infolist()))
        elif e in IMG:
            return None
        else:
            t = open(p, 'rb').read().decode('utf-8', 'ignore')
    except Exception:
        return ''
    return re.sub(r'\s+', ' ', t).strip()

def paginas(p):
    if not p.lower().endswith('.pdf'): return None
    try:
        o = subprocess.run(['pdfinfo', p], capture_output=True, timeout=60).stdout.decode('utf-8', 'ignore')
        return int(re.search(r'Pages:\s+(\d+)', o).group(1))
    except Exception:
        return None

def sim_texto(a, b):
    wa, wb = a.split(), b.split()
    if not wa or not wb: return None
    return round(difflib.SequenceMatcher(None, wa[:20000], wb[:20000], autojunk=False).ratio(), 3)

def sim_imagen(a, b):
    from PIL import Image
    A = Image.open(a).convert('L').resize((64, 64)); B = Image.open(b).convert('L').resize((64, 64))
    pa, pb = list(A.getdata()), list(B.getdata())
    return round(1 - sum(abs(x - y) for x, y in zip(pa, pb)) / (64 * 64 * 255), 3)

def comparar_par(a, b):
    if sha(a) == sha(b): return {'clase': 'IDENTICO', 'similitud': 1.0, 'criterio': 'SHA256_IDENTICO'}
    ext = a.rsplit('.', 1)[-1].lower()
    if ext in IMG:
        s = sim_imagen(a, b); c = 'MISMO_CONTENIDO' if s >= 0.97 else ('CASI_IGUAL' if s >= 0.90 else 'VERSION_DISTINTA')
        return {'clase': c, 'similitud': s, 'criterio': 'IMAGEN_PERCEPTUAL'}
    s = sim_texto(texto(a) or '', texto(b) or '')
    pa, pb = paginas(a), paginas(b)
    if s is None: return {'clase': 'SIN_DATOS', 'similitud': None, 'criterio': 'SIN_TEXTO (verificar visualmente)', 'paginas': [pa, pb]}
    c = 'MISMO_CONTENIDO' if (s >= 0.98 and pa == pb) else ('CASI_IGUAL' if s >= 0.90 else 'VERSION_DISTINTA')
    return {'clase': c, 'similitud': s, 'criterio': 'TEXTO_EXTRAIDO' + ('+PAGINAS' if pa else ''), 'paginas': [pa, pb]}

def cmd_candidatos(a):
    filas = list(csv.DictReader(open(a.manifiesto, encoding='utf-8-sig'), delimiter=';'))
    ult = {}
    for f in filas:
        if f.get('RutaRelativa'): ult[f['RutaRelativa'].lower()] = f
    g = collections.defaultdict(list)
    for f in ult.values():
        r = f['RutaRelativa']
        if f['Estado'] not in VIGENTES or r.lower().startswith('_duplicados_revisar'): continue
        k = clave(r)
        if k[2] in NATIVOS: continue
        g[k].append(f)
    out = []; n = 0
    for k, v in sorted(g.items()):
        if len(v) < 2: continue
        if a.desde and not any((f.get('FechaClasificacion') or '') >= a.desde for f in v): continue
        n += 1
        for f in v: out.append({'Grupo': f'C{n:04d}', 'RutaRelativa': f['RutaRelativa'], 'Tamano': f.get('Tamano', '')})
    w = csv.DictWriter(open(a.salida, 'w', encoding='utf-8-sig', newline=''), fieldnames=['Grupo', 'RutaRelativa', 'Tamano'], delimiter=';')
    w.writeheader(); w.writerows(out)
    print(json.dumps({'grupos': n, 'archivos': len(out)}))

def cmd_comparar(a):
    lote = list(csv.DictReader(open(a.lote, encoding='utf-8-sig'), delimiter=';'))
    grupos = collections.defaultdict(list)
    for f in lote:
        if os.path.exists(f['RutaLocal']): grupos[f['Grupo']].append(f)
    nuevo = not os.path.exists(a.informe)
    hechos = set()
    if not nuevo:
        for f in csv.DictReader(open(a.informe, encoding='utf-8-sig'), delimiter=';'): hechos.add(f['RutaRelativa'].lower())
    filas = []; stat = collections.Counter()
    for gid, ms in grupos.items():
        if len(ms) < 2 or all(m['RutaRelativa'].lower() in hechos for m in ms): continue
        base = ms[0]; res = [{'clase': 'BASE', 'similitud': 1.0, 'criterio': ''}] + [comparar_par(base['RutaLocal'], m['RutaLocal']) for m in ms[1:]]
        iguales = [i for i, r in enumerate(res) if r['clase'] in ('BASE', 'IDENTICO', 'MISMO_CONTENIDO')]
        conservar = max(iguales, key=lambda i: os.path.getsize(ms[i]['RutaLocal'])) if len(iguales) > 1 else None
        for i, (m, r) in enumerate(zip(ms, res)):
            if conservar is not None and i in iguales:
                prop = 'CONSERVAR' if i == conservar else ('APARTAR_DUPLICADO_EXACTO' if r['clase'] == 'IDENTICO' or (i == 0 and res[conservar]['clase'] == 'IDENTICO') else 'APARTAR_COPIA_SIMILAR (requiere confirmacion)')
            elif r['clase'] == 'SIN_DATOS': prop = 'REVISAR (sin texto: comparar visualmente)'
            elif r['clase'] == 'CASI_IGUAL': prop = 'REVISAR (diferencias menores: posible reemision o version)'
            elif r['clase'] == 'VERSION_DISTINTA': prop = 'VERSION_DISTINTA: conservar (familia de versiones, M2)'
            else: prop = 'REVISAR'
            filas.append([gid, m['RutaRelativa'], r.get('criterio', ''), '' if r['similitud'] is None else f"{r['similitud']:.3f}", os.path.getsize(m['RutaLocal']), prop, paginas(m['RutaLocal']) or '', ''])
            stat[prop.split(' ')[0]] += 1
    with open(a.informe, 'a', encoding='utf-8-sig' if nuevo else 'utf-8', newline='') as f:
        w = csv.writer(f, delimiter=';', lineterminator='\r\n')
        if nuevo: w.writerow(['Grupo', 'RutaRelativa', 'Criterio', 'SimilitudConPrimero', 'Tamano', 'Propuesta', 'Paginas', 'NombreOriginal'])
        w.writerows(filas)
    print(json.dumps(dict(stat)))

def main():
    ap = argparse.ArgumentParser(); sp = ap.add_subparsers(dest='cmd', required=True)
    c = sp.add_parser('candidatos'); c.add_argument('--manifiesto', required=True); c.add_argument('--desde', default=''); c.add_argument('--salida', default='candidatos.csv')
    c = sp.add_parser('comparar'); c.add_argument('--lote', required=True); c.add_argument('--informe', required=True)
    c = sp.add_parser('par'); c.add_argument('--a', required=True); c.add_argument('--b', required=True)
    a = ap.parse_args()
    if a.cmd == 'candidatos': cmd_candidatos(a)
    elif a.cmd == 'comparar': cmd_comparar(a)
    else: print(json.dumps(comparar_par(a.a, a.b), ensure_ascii=False))

if __name__ == '__main__': main()
