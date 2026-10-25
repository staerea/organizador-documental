#!/usr/bin/env python3
"""Pruebas del M12 (casi duplicados) v1.11.4."""
import csv, json, os, subprocess, sys, tempfile
from reportlab.pdfgen import canvas
from PIL import Image
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); M = os.path.join(R, 'src', 'm12', 'm12_casi_duplicados.py')
fallos = 0
def T(n, c):
    global fallos
    if not c: fallos += 1
    print(f'{n:<66} {"OK" if c else "FALLO"}')
def pdf(p, lineas, titulo='x', comprimir=1):
    c = canvas.Canvas(p, pageCompression=comprimir); c.setTitle(titulo)
    for pag in lineas:
        y = 800
        for l in pag: c.drawString(50, y, l); y -= 14
        c.showPage()
    c.save()
def par(a, b): return json.loads(subprocess.run([sys.executable, M, 'par', '--a', a, '--b', b], capture_output=True, text=True).stdout)
d = tempfile.mkdtemp()
txt = [[f'Linea {i} del informe tecnico de teledeteccion sobre parcelas agricolas' for i in range(40)] for _ in range(3)]
pdf(f'{d}/a.pdf', txt, 'A', 1); pdf(f'{d}/b.pdf', txt, 'B distinto', 0)
otro = [[f'Presupuesto {i} con importes y condiciones completamente diferentes {i*7}' for i in range(40)]]
pdf(f'{d}/c.pdf', otro)
import shutil; shutil.copy(f'{d}/a.pdf', f'{d}/a2.pdf')
T('T120 mismo archivo: IDENTICO', par(f'{d}/a.pdf', f'{d}/a2.pdf')['clase'] == 'IDENTICO')
r = par(f'{d}/a.pdf', f'{d}/b.pdf')
T('T121 mismo texto y paginas, distinto binario: MISMO_CONTENIDO', r['clase'] == 'MISMO_CONTENIDO')
T('T122 contenido distinto: VERSION_DISTINTA', par(f'{d}/a.pdf', f'{d}/c.pdf')['clase'] == 'VERSION_DISTINTA')
im = Image.new('RGB', (400, 300), 'white')
for x in range(100, 300):
    for y in range(80, 220): im.putpixel((x, y), (200, 30, 30))
im.save(f'{d}/i1.png'); im.resize((800, 600)).save(f'{d}/i2.png'); Image.new('RGB', (400, 300), 'black').save(f'{d}/i3.png')
T('T123 imagen reescalada: MISMO_CONTENIDO', par(f'{d}/i1.png', f'{d}/i2.png')['clase'] == 'MISMO_CONTENIDO')
T('T124 imagen distinta: VERSION_DISTINTA', par(f'{d}/i1.png', f'{d}/i3.png')['clase'] == 'VERSION_DISTINTA')
man = f'{d}/m.csv'
with open(man, 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f, delimiter=';'); w.writerow(['RutaRelativa','SHA256','Tamano','FechaMod','Area','Estado','NombreOriginal','FechaClasificacion','VersionSkill'])
    w.writerow(['07\\A\\Informe.pdf','1','1','0','07','HEREDADO','','2026-10-03','1.0'])
    w.writerow(['07\\A\\Informe_v2.pdf','2','1','0','07','MOVIDO','x (1).pdf','2026-10-20','1.11'])
    w.writerow(['07\\A\\Otro.pdf','3','1','0','07','MOVIDO','y.pdf','2026-10-20','1.11'])
    w.writerow(['07\\B\\Informe_v3.pdf','4','1','0','07','MOVIDO','z.pdf','2026-10-20','1.11'])
    w.writerow(['_DUPLICADOS_REVISAR\\07\\A\\Informe__COPIA_1.pdf','1','1','0','_D','DUPLICADO_VERIFICADO','','2026-10-20','1.11'])
    w.writerow(['07\\A\\Doc.gdoc','','1','0','07','MOVIDO','','2026-10-20','1.11'])
    w.writerow(['07\\A\\Doc_v2.gdoc','','1','0','07','MOVIDO','','2026-10-20','1.11'])
out = json.loads(subprocess.run([sys.executable, M, 'candidatos', '--manifiesto', man, '--salida', f'{d}/c.csv'], capture_output=True, text=True).stdout)
filas = list(csv.DictReader(open(f'{d}/c.csv', encoding='utf-8-sig'), delimiter=';'))
T('T125 candidatos: 1 grupo (misma carpeta, sin copias apartadas ni nativos)', out['grupos'] == 1 and {f['RutaRelativa'] for f in filas} == {'07\\A\\Informe.pdf', '07\\A\\Informe_v2.pdf'})
out2 = json.loads(subprocess.run([sys.executable, M, 'candidatos', '--manifiesto', man, '--desde', '2026-10-25', '--salida', f'{d}/c2.csv'], capture_output=True, text=True).stdout)
T('T126 candidatos --desde: sin grupos nuevos', out2['grupos'] == 0)
with open(f'{d}/lote.csv', 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f, delimiter=';'); w.writerow(['Grupo','RutaRelativa','RutaLocal'])
    w.writerow(['C1','07\\A\\Informe.pdf',f'{d}/a.pdf']); w.writerow(['C1','07\\A\\Informe_v2.pdf',f'{d}/b.pdf']); w.writerow(['C1','07\\A\\Informe_v3.pdf',f'{d}/c.pdf'])
subprocess.run([sys.executable, M, 'comparar', '--lote', f'{d}/lote.csv', '--informe', f'{d}/inf.csv'], capture_output=True)
inf = list(csv.DictReader(open(f'{d}/inf.csv', encoding='utf-8-sig'), delimiter=';'))
prop = {f['RutaRelativa']: f['Propuesta'] for f in inf}
T('T127 informe: conserva una, aparta la similar, respeta la version', sum(p == 'CONSERVAR' for p in prop.values()) == 1 and sum(p.startswith('APARTAR_COPIA_SIMILAR') for p in prop.values()) == 1 and prop['07\\A\\Informe_v3.pdf'].startswith('VERSION_DISTINTA'))
subprocess.run([sys.executable, M, 'comparar', '--lote', f'{d}/lote.csv', '--informe', f'{d}/inf.csv'], capture_output=True)
T('T128 segunda ejecucion: no duplica filas del informe', len(list(csv.DictReader(open(f'{d}/inf.csv', encoding='utf-8-sig'), delimiter=';'))) == 3)
T('T129 el M12 no modifica ni borra los archivos comparados', all(os.path.exists(f'{d}/{n}') for n in ('a.pdf','b.pdf','c.pdf','i1.png','i2.png','i3.png')))
print(f'FALLOS: {fallos}')
