import os,sys
R0=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); D=os.path.join(R0,'src'); B=os.path.join(R0,'dist'); os.makedirs(B,exist_ok=True)
comun=open(os.path.join(D,'comun.ps1'),encoding='utf-8').read().strip('\n')
def w(name,txt):
    txt=txt.replace('\r\n','\n').replace('\n','\r\n')
    open(os.path.join(B,name),'wb').write(b'\xef\xbb\xbf'+txt.encode('utf-8'))
for src,dst in [('Vigilante_Raiz.src.ps1','Vigilante_Raiz.ps1'),('Aplicar_Plan.src.ps1','Aplicar_Plan.ps1'),('Verificar_Integridad.src.ps1','Verificar_Integridad.ps1'),
                ('Inventariar_Raiz.src.ps1','Inventariar_Raiz.ps1'),('Copia_Verificada.src.ps1','Copia_Verificada.ps1'),('Configurar_Plataforma.src.ps1','Configurar_Plataforma.ps1'),
                ('Instalar_Vigilante.src.ps1','Instalar_Vigilante.ps1'),('Diagnosticar_Vigilante.ps1','Diagnosticar_Vigilante.ps1')]:
    t=open(os.path.join(D,src),encoding='utf-8-sig').read()
    if '#COMUN#' in t: t=t.replace('#COMUN#',comun,1)
    w(dst,t)
h=open(os.path.join(D,'gen_head.src.ps1'),encoding='utf-8-sig').read().replace('#COMUN#',comun,1)
p=open(os.path.join(D,'plantilla.html'),encoding='utf-8').read(); t=open(os.path.join(D,'gen_tail.src.ps1'),encoding='utf-8-sig').read()
assert "\n'@" not in p
w('Generar_Panel_Duplicados.ps1',h+p+t)
w('PANEL_DUPLICADOS.html',p)
for b in ['CONFIGURAR_PLATAFORMA.bat','DIAGNOSTICAR_VIGILANTE.bat']:
    t=open(os.path.join(D,b),encoding='utf-8').read().replace('\r\n','\n').replace('\n','\r\n'); open(os.path.join(B,b),'wb').write(t.encode())
import shutil; shutil.copy(os.path.join(R0,'config','config_plataforma.csv'),B)
print(sorted(os.listdir(B)))

os.makedirs(os.path.join(B,'m14'),exist_ok=True)
for f in os.listdir(os.path.join(D,'m14')):
    if f.endswith('.py'): shutil.copy(os.path.join(D,'m14',f),os.path.join(B,'m14',f))
os.makedirs(os.path.join(B,'m12'),exist_ok=True)
for f in os.listdir(os.path.join(D,'m12')):
    if f.endswith('.py'): shutil.copy(os.path.join(D,'m12',f),os.path.join(B,'m12',f))
for f in os.listdir(os.path.join(R0,'config')):
    shutil.copy(os.path.join(R0,'config',f),os.path.join(B,f))
for f in ['Deshacer.ps1','Desinstalar_Vigilante.ps1','REANUDAR_VIGILANTE.bat']:
    shutil.copy(os.path.join(D,f),os.path.join(B,f))

# v1.11.2: lanzador sin ventana (VBScript: ASCII, CRLF y SIN BOM, o wscript no lo interpreta)
v=open(os.path.join(D,'Vigilante_Oculto.vbs'),encoding='utf-8').read(); v.encode('ascii')
open(os.path.join(B,'Vigilante_Oculto.vbs'),'wb').write(v.replace('\r\n','\n').replace('\n','\r\n').encode('ascii'))
