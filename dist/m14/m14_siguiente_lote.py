#!/usr/bin/env python3
"""M14 - seleccion del siguiente lote a indexar (organizador-documental v1.11).

Uso: m14_siguiente_lote.py --manifiesto manifiesto_documental.csv --estado m14_estado.csv --salida lote_pendiente.csv
                            [--max 60] [--max-mb 300] [--max-mb-archivo 50]
Toma la ultima fila de cada ruta del manifiesto (solo anexado), descarta borrados, _DUPLICADOS_REVISAR, _ORGANIZACION,
la carpeta de entrada y formatos sin texto, y prioriza por area. Escribe SHA256;RutaRelativa;Tamano e imprime la cobertura.
"""
import argparse, csv, os
EXT = {'.pdf', '.docx', '.xlsx', '.pptx', '.odt', '.txt', '.md', '.csv', '.html', '.htm'}
PRIORIDAD = ['01', '02', '08', '03', '07', '05', '04', '10', '11', '06', '99', '09']
ap = argparse.ArgumentParser()
ap.add_argument('--manifiesto', required=True); ap.add_argument('--estado', required=True); ap.add_argument('--salida', required=True)
ap.add_argument('--max', type=int, default=60); ap.add_argument('--max-mb', type=float, default=300); ap.add_argument('--max-mb-archivo', type=float, default=50)
ap.add_argument('--entrada', default='INPUT')
a = ap.parse_args()
ult = {}
with open(a.manifiesto, encoding='utf-8-sig') as f:
    for r in csv.DictReader(f, delimiter=';'):
        ult[r['RutaRelativa'].lower()] = r
hechos = set()
if os.path.exists(a.estado):
    with open(a.estado, encoding='utf-8-sig') as f:
        for r in csv.DictReader(f, delimiter=';'):
            if not r['Resultado'].startswith('ERROR'):
                hechos.add(r['SHA256'])
excl = ('_duplicados_revisar', '_organizacion', a.entrada.lower(), 'nuevos')
cand, total, vistos = [], set(), set()
for r in ult.values():
    rel = r['RutaRelativa']; top = rel.split('\\')[0].lower()
    if r['Estado'].startswith('BORRADO') or top in excl or top.startswith('_') or not r['SHA256']:
        continue
    if os.path.splitext(rel)[1].lower() not in EXT or r['SHA256'] in vistos:
        continue
    vistos.add(r['SHA256']); total.add(r['SHA256'])
    if r['SHA256'] in hechos:
        continue
    t = int(r['Tamano'] or 0)
    if t > a.max_mb_archivo * 2**20:
        continue
    pr = PRIORIDAD.index(top[:2]) if top[:2] in PRIORIDAD else len(PRIORIDAD)
    cand.append((pr, rel.lower(), r['SHA256'], rel, t))
cand.sort(); sel, mb = [], 0.0
for c in cand:
    if len(sel) >= a.max or mb + c[4] / 2**20 > a.max_mb:
        continue
    sel.append(c); mb += c[4] / 2**20
with open(a.salida, 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.writer(f, delimiter=';', lineterminator='\r\n'); w.writerow(['SHA256', 'RutaRelativa', 'Tamano'])
    for c in sel:
        w.writerow([c[2], c[3], c[4]])
cub = len(total & hechos) / len(total) * 100 if total else 100.0
print(f'lote={len(sel)} MB={mb:.1f} pendientes={len(cand)} indexables={len(total)} cobertura={cub:.1f}%')
