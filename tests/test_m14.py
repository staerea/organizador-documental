"""Pruebas del extractor M14 (python3 tests/test_m14.py)."""
import csv, os, subprocess, sys, tempfile, zipfile
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EX = os.path.join(RAIZ, 'src', 'm14', 'm14_extraer.py'); SIG = os.path.join(RAIZ, 'src', 'm14', 'm14_siguiente_lote.py')
sys.path.insert(0, os.path.dirname(EX)); import m14_extraer as m
fallos = 0
def T(n, c):
    global fallos; fallos += (not c); print(f"{n:<64} {'OK' if c else 'FALLO'}")
def cif(l, d):
    for c in '0123456789ABCDEFGHIJ':
        if m.cif_valido(l, d, c): return l + d + c
T('M1 CIF valido calculado (B1234567x)', bool(cif('B', '1234567')))
T('M1b CIF con control erroneo rechazado', not m.cif_valido('B', '1234567', 'Z'))
C = cif('B', '7310584')
texto = (f"AYUNTAMIENTO DE LLERENA\nExcmo. Ayuntamiento de Llerena\nExpediente nº 2025/0457-OBR\n"
         f"Fecha: 14/03/2025\nEmitido por Agencia Estatal de Seguridad Aérea (AESA) el 3 de febrero de 2026\n"
         f"Cliente: Aridesur Ingenieria S.L., CIF {C}\nDNI del firmante 12345678Z, IBAN ES9121000418450200051332\n"
         f"Ref. catastral 9872023VH5797S0001WX\nFactura nº F-2025-118\n")
with tempfile.TemporaryDirectory() as d:
    docx = os.path.join(d, 'a.docx')
    with zipfile.ZipFile(docx, 'w') as z:
        z.writestr('word/document.xml', '<w:document><w:body>' + ''.join(f'<w:p><w:r><w:t>{l}</w:t></w:r></w:p>' for l in texto.split('\n')) + '</w:body></w:document>')
    from reportlab.pdfgen import canvas
    pdf = os.path.join(d, 'b.pdf'); c = canvas.Canvas(pdf); y = 800
    for l in texto.replace('é', 'e').replace('º', 'o').split('\n'):
        c.drawString(40, y, l); y -= 16
    c.save()
    vacio = os.path.join(d, 'c.pdf'); c = canvas.Canvas(vacio); c.save()
    lote = os.path.join(d, 'lote.csv')
    with open(lote, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f, delimiter=';'); w.writerow(['SHA256', 'RutaRelativa', 'RutaLocal'])
        w.writerow(['s1', '01_STAEREA_PROYECTOS\\Llerena_Pallares\\Memoria.docx', docx])
        w.writerow(['s2', '02_STAEREA_ADMIN\\Facturas\\Factura.pdf', pdf])
        w.writerow(['s3', '09_PERSONAL_SENSIBLE\\Informe.docx', docx])
        w.writerow(['s4', '02_STAEREA_ADMIN\\Escaneo.pdf', vacio])
    idx, est = os.path.join(d, 'idx.csv'), os.path.join(d, 'est.csv')
    out = subprocess.run([sys.executable, EX, '--lote', lote, '--indice', idx, '--estado', est], capture_output=True, text=True)
    T('M2 el extractor termina sin error', out.returncode == 0)
    rows = list(csv.DictReader(open(idx, encoding='utf-8-sig'), delimiter=';'))
    by = lambda s: {(r['Campo'], r['Valor']) for r in rows if r['SHA256'] == s}
    s1 = by('s1')
    T('M3 proyecto desde la ruta', ('PROYECTO', 'Llerena_Pallares') in s1)
    T('M3b organismos AESA y Ayuntamiento de Llerena', ('ORGANISMO', 'AESA') in s1 and ('ORGANISMO', 'Ayuntamiento de Llerena') in s1)
    T('M3c expediente', ('EXPEDIENTE', '2025/0457-OBR') in s1)
    T('M3d fecha documento 2025-03-14', ('FECHA_DOCUMENTO', '2025-03-14') in s1)
    T('M3e fecha textual 2026-02-03', ('FECHA', '2026-02-03') in s1)
    T('M3f CIF de empresa y razon social', ('CIF_EMPRESA', C) in s1 and any(c == 'EMPRESA' and 'Aridesur' in v for c, v in s1))
    T('M3g referencia catastral y factura', ('REF_CATASTRAL', '9872023VH5797S0001WX') in s1 and ('NUM_FACTURA', 'F-2025-118') in s1)
    todo = open(idx, encoding='utf-8-sig').read()
    T('M4 nunca guarda DNI ni IBAN', '12345678Z' not in todo and 'ES9121' not in todo)
    T('M5 PDF con texto tambien extrae', ('ORGANISMO', 'Ayuntamiento de Llerena') in by('s2'))
    s3 = by('s3')
    T('M6 09_PERSONAL_SENSIBLE: solo tipo y fecha', {c for c, _ in s3} <= {'TIPO_DOCUMENTO', 'FECHA_DOCUMENTO'})
    estado = {r['SHA256']: r['Resultado'] for r in csv.DictReader(open(est, encoding='utf-8-sig'), delimiter=';')}
    T('M7 escaneo sin texto marcado SIN_TEXTO', estado.get('s4') == 'SIN_TEXTO' and estado.get('s1') == 'OK')
    man = os.path.join(d, 'man.csv')
    with open(man, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f, delimiter=';'); w.writerow(['RutaRelativa', 'SHA256', 'Tamano', 'FechaMod', 'Area', 'Estado', 'NombreOriginal', 'FechaClasificacion', 'VersionSkill'])
        w.writerow(['01_STAEREA_PROYECTOS\\Llerena_Pallares\\Memoria.docx', 's1', '100', '', '', 'MOVIDO', '', '', ''])
        w.writerow(['02_STAEREA_ADMIN\\Nuevo.pdf', 's9', '100', '', '', 'MOVIDO', '', '', ''])
        w.writerow(['_DUPLICADOS_REVISAR\\x__COPIA_1.pdf', 's8', '100', '', '', 'DUPLICADO_VERIFICADO', '', '', ''])
        w.writerow(['03_FORMACION\\Video.mp4', 's7', '100', '', '', 'MOVIDO', '', '', ''])
        w.writerow(['01_STAEREA_PROYECTOS\\Borrado.pdf', 's6', '100', '', '', 'BORRADO_POR_USUARIO', '', '', ''])
    sal = os.path.join(d, 'sig.csv')
    o = subprocess.run([sys.executable, SIG, '--manifiesto', man, '--estado', est, '--salida', sal], capture_output=True, text=True).stdout
    sel = [r['SHA256'] for r in csv.DictReader(open(sal, encoding='utf-8-sig'), delimiter=';')]
    T('M8 siguiente lote: solo pendientes indexables', sel == ['s9'] and 'cobertura=50.0%' in o)
print(f'FALLOS: {fallos}')
sys.exit(1 if fallos else 0)
