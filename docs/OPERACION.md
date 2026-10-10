# Operación

## Requisitos para que funcione

| Requisito | Por qué | Síntoma si falta |
|---|---|---|
| Equipo encendido (no suspendido) y sesión de Windows iniciada | La tarea del vigilante es del usuario (cada `IntervaloVigilanteMin`, 60 min por defecto, sin ventana) | Sin filas nuevas en el latido durante más de 1,5 intervalos; la tarea horaria avisa «VIGILANTE DETENIDO» |
| Google Drive para escritorio abierto (unidad `G:` montada) | La raíz está en `G:` | `vigilante_sin_raiz.txt`; la tarea horaria avisa «RAÍZ NO DISPONIBLE» |
| App de escritorio de Claude abierta | La tarea horaria accede al equipo a través de ella | La tarea horaria termina sin acceso al equipo |

### Reducir la dependencia (opcional, lo hace el usuario)

- **Que el vigilante funcione sin sesión iniciada.** En el Programador de tareas, abra la tarea `Organizador_DESCARGAS_Vigilante` y, en la pestaña «General», elija «Ejecutar tanto si el usuario inició sesión como si no». Windows pedirá la contraseña: introdúzcala usted. Limitación: sin sesión, Google Drive para escritorio no suele estar montado, así que solo sirve si la raíz es una carpeta local.
- **Evitar la suspensión en horario de trabajo.** Panel de control → Opciones de energía, mientras el equipo esté enchufado.
- **Independencia total del PC.** Haría falta un servidor o una máquina siempre encendida con Drive montado. Queda fuera del alcance actual.

## Configuración

`CONFIGURAR_PLATAFORMA.bat` (doble clic en la raíz) muestra y cambia:
1. la raíz documental;
2. la carpeta de entrada (por defecto `INPUT`);
3. las carpetas donde se recogen los CSV del panel (por defecto, Descargas del navegador; varias separadas por `|`);
4. la restauración de los valores por defecto.

## Activar la copia de seguridad (M15)

1. Conecte el disco externo y cree una carpeta, por ejemplo `E:\COPIA_DESCARGAS`.
2. Pida a Claude que active el M15 con ese destino, o edite la fila M15 de `_ORGANIZACION\config_modulos.csv`: `Activo=SI` y `Destino=E:\COPIA_DESCARGAS`.
3. La primera copia completa puede tardar varias pasadas (50 GB como máximo por pasada). Revise `_ORGANIZACION\copia_<AAAAMMDD>.csv`.
4. Desconecte el disco cuando no lo use: así también protege frente a ransomware (regla 3‑2‑1).

## Diagnóstico rápido

| Síntoma | Dónde mirar | Acción |
|---|---|---|
| `planes_pendientes` no se vacía | Latido y `vigilante.lock` (fecha y fase) | Ver el estado de la tarea de Windows; ejecutar `INSTALAR_VIGILANTE.bat` |
| Solicitudes de borrado sin efecto | `borrados_solicitudes\`, `procesadas\`, `resultado_*.csv` | Comprobar que el navegador descarga en una carpeta de recogida (`CONFIGURAR_PLATAFORMA.bat`) |
| Alerta M16 | `ALERTA_INTEGRIDAD.txt`, `integridad_<AAAAMM>.csv` | Revisar; si es una falsa alarma, ejecutar `REANUDAR_VIGILANTE.bat` |
| El panel no cambia | `panel_ultimo.json`, latido `PANEL_*` | Recargar con F5; el panel se regenera como máximo cada hora |

## Ejecución sin ventana (v1.11.2)

La tarea de Windows lanza `wscript.exe //B //Nologo Vigilante_Oculto.vbs`. `wscript.exe` no tiene consola y el `.vbs` abre PowerShell con la ventana oculta desde su creación, de modo que no aparece ni parpadea ninguna ventana (con `powershell.exe -WindowStyle Hidden` lanzado directamente por el Programador de tareas, la consola se crea visible y se oculta después: parpadeo). Requisito: VBScript, característica opcional de Windows en retirada progresiva (fase 1, Windows 11 24H2: instalada y activa por defecto; fase 2, hacia 2027: desactivada por defecto). Si `wscript.exe` o el `.vbs` faltan, `Instalar_Vigilante.ps1` vuelve al método anterior y lo indica. Se descartó `conhost.exe --headless`: las reglas de detección Sigma lo tratan como técnica sospechosa y lo marcarían los antivirus/EDR.

Cambiar el intervalo o el modo de lanzamiento requiere volver a registrar la tarea: `INSTALAR_VIGILANTE.bat` (o la opción 4 de `CONFIGURAR_PLATAFORMA.bat`, que lo hace sola).

## Desplegar una versión

0. **Puerta de despliegue (v1.11.2):** inventariar solicitudes pendientes (carpetas de recogida y `borrados_solicitudes`) y planes en `planes_pendientes`, presentarlos al usuario y obtener su confirmación expresa. Desplegar con `ModoBorrados=INFORME` en `config_plataforma.csv`; pasar a `ACTIVO` solo con autorización expresa tras revisar los `informe_*.csv` de la primera pasada.
1. Ejecute `python3 tools/build.py` y después `bash tests/run_all.sh`; debe terminar sin fallos.
2. Copie `dist/*.ps1` a `_ORGANIZACION\`. No sobrescriba los `config_*.csv` del equipo: añada solo las claves nuevas.
3. Copie `dist/m14/*.py` a `_ORGANIZACION\modulos\M14\`.
4. Copie `dist/*.bat` a la raíz, `dist/Vigilante_Oculto.vbs` a `_ORGANIZACION\` y `dist/PANEL_DUPLICADOS.html` a `_DUPLICADOS_REVISAR\`.
5. Verifique que el contenido desplegado coincide con `dist/` (SHA‑256).
6. Revise en la siguiente pasada el latido (`FIN_OK`) y los eventos esperados de la versión.
7. Actualice el bundle `_ORGANIZACION\repositorio\organizador-documental.bundle` (`git bundle create … --all`).

## Reversión

- **Movimientos:** `Deshacer.ps1 -Registro <registro_*.csv>`; los del vigilante constan en `vigilante_<AAAAMM>.csv`.
- **Borrados:** papelera de Google Drive (30 días).
- **Versión de scripts:** volver a desplegar `dist/` desde la etiqueta anterior (`git checkout vX.Y.Z`).
