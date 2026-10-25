# Historial de versiones

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); versiones `MAYOR.MENOR.PARCHE`.

## [1.11.4] - 2026-10-25 (construida y probada: 158/158; despliegue pendiente de la puerta de despliegue)
- `Aplicar_Plan`: toda fila `MOVER` de un archivo se compara por SHA-256 con los archivos vigentes del manifiesto y con las filas anteriores del mismo plan; si ya existe, se aparta a `_DUPLICADOS_REVISAR` como `__COPIA_n` verificada (registro `DUPLICADO_DETECTADO_AL_APLICAR`) en lugar de entrar con `_vN`. 9 pruebas nuevas (prueba11).
- M12 operativo: `modulos\M12\m12_casi_duplicados.py` (candidatos / comparar / par), solo lectura; `config_modulos`: M12 `SI;INFORME;Frecuencia=DIARIA`. 10 pruebas nuevas (test_m12).
- Tarea horaria y skill: no se numera `_vN` sin comparar contenido; las copias de contenido igual quedan en espera y van al informe del M12 para confirmación del usuario.
- Nuevo `DIAGNOSTICAR_VIGILANTE.bat` + `Diagnosticar_Vigilante.ps1` (solo lectura): estado y último resultado de la tarea programada, disponibilidad de VBScript, bloqueos/pausa, últimas líneas del latido e historial del Programador. Escribe `_ORGANIZACION\diagnostico_vigilante_<fecha>.txt`. **Desplegado** (no tiene efectos).
- Vigilante: `CONFIGURAR_PLATAFORMA.bat` y `DIAGNOSTICAR_VIGILANTE.bat` se excluyen de la recogida de la raíz (el primero acabó en `INPUT` desde la v1.11). En el equipo se aplica de momento con `_ORGANIZACION\excluir_raiz.txt`; el cambio del script queda **pendiente de despliegue** por la puerta de despliegue.
- Incidencia 17-10/20-10: 238 bytes NUL intercalados en `manifiesto_documental.csv` (fila del original de `dock_technical_paper.pdf`) provocaban `ERROR_ELEMENTO: Caracteres no válidos en la ruta de acceso` en cada pasada. Reparado eliminando solo los NUL (28.598 filas íntegras, 9 campos); copia del archivo dañado en `_ORGANIZACION\alertas\manifiesto_documental_CON_NUL_20261025.csv`.
- Revisión de «versiones» del 25-10 (M12 ejecutado en modo informe): 157 grupos con el mismo nombre base en la misma carpeta; 111 con sufijo `_vN` asignado por el renombrado (convención «(1)»→`_v2` y regla «hash distinto = versión»). Resultado: 2 grupos idénticos byte a byte, 49 con el mismo contenido (re-descargas o re-exportaciones), 13 casi iguales, 34 versiones reales, 13 sin analizar (nativos Google o >60 MB). Informe en `_ORGANIZACION\modulos\M12\casi_duplicados_20261025.csv`.
- Causas identificadas (pendiente de corrección): (a) `Aplicar_Plan` no comprueba el SHA-256 de las filas `MOVER` frente al manifiesto ni frente al resto del plan; (b) la convención de nombres convierte «(n)» en `_vN` sin comparar contenido; (c) M2 y M12 están `BAJO_DEMANDA` y nunca se habían ejecutado.
- Pendiente: el vigilante no ejecuta pasadas desde el 20-10 20:36 aunque el equipo se ha usado después; diagnóstico con el nuevo .bat.

## [1.11.3] — 2026-10-10
### Cambiado
- Tarea horaria con **triaje ligero** (ahorro de cuota): comprueba salud, planes pendientes, entrada, M14 e informes diarios leyendo solo archivos pequeños (los grandes se analizan en el contenedor sin volcarlos) y **solo carga el skill si hay un bloque que clasificar**; sin trabajo ni avisos termina sin informe. No cambia ningún resultado ni ningún script del equipo.

## [1.11.2] — 2026-10-10
### Seguridad (incidencia del 10‑10‑2026: seis solicitudes antiguas ejecutadas al desplegar la v1.11.1 sin confirmación expresa)
- **Caducidad de solicitudes de borrado** (`CaducidadSolicitudHoras`, 24 h): una solicitud no iniciada más antigua, o sin fecha válida, pasa a `borrados_solicitudes\pendientes_confirmacion` (latido `SOLICITUDES_CADUCADAS`) y el panel permite volver a marcar esas copias.
- **Modo de borrado** (`ModoBorrados`): `INFORME` por defecto (verifica y escribe `informe_<solicitud>.csv` con `SE_BORRARIA`, latido `BORRADOS_SOLO_INFORME`, sin borrar) o `ACTIVO`. Valor ausente o no válido = `INFORME`. Todo despliegue se hace en `INFORME`.
- Puerta de despliegue y regla de comunicación en `docs/GOBERNANZA.md` y en el skill.
### Cambiado
- **Periodicidad del vigilante configurable** (`IntervaloVigilanteMin`, 60 min por defecto; antes 10). Límite por pasada 55 min y presupuestos ampliados: RAÍZ 25 min, BORRADOS 10 min, planes nuevos hasta el min 30, panel hasta el min 45, bloqueo huérfano a los 65 min.
- **Ejecución sin ventana:** la tarea lanza `wscript.exe` con `Vigilante_Oculto.vbs` (PowerShell oculto desde el inicio); retorno automático al método anterior si VBScript no está disponible.
- M16: la ventana de cambios masivos es el intervalo del vigilante (antes 10 min fijos).
- `CONFIGURAR_PLATAFORMA.bat`: intervalo (vuelve a registrar la tarea), caducidad y modo de borrado (ACTIVO exige escribir «SI»).
- Tarea horaria: «VIGILANTE DETENIDO» si no hay `FIN_OK` en 1,5 intervalos; informa de solicitudes caducadas, del modo INFORME y de los `informe_*.csv`.
- Pruebas: `prueba10.ps1` (19 casos); total 139.

## [1.11.1] — 2026-10-10
### Corregido
- **Incidencia 07‑10‑2026:** un acceso directo de Google Docs (`.gdoc`) en la raíz no se podía leer (`Get-FileHash`: «Función incorrecta») y su error abortaba la pasada completa. Desde el 07‑10 a las 14:43 todas las pasadas terminaron en `FIN_ERROR`: la raíz acumuló unos 200 elementos y no se aplicó ningún plan durante tres días. Ahora cada elemento de la fase RAÍZ se procesa en su propio bloque de errores (`ERROR_ELEMENTO` en el registro, latido `RAIZ_ELEMENTOS_CON_ERROR`) y la pasada continúa.
- Los archivos nativos de Google (`.gdoc`, `.gsheet`, `.gslides`…) se encolan sin hash (`EN_COLA_GOOGLE_NATIVO`) y `Aplicar_Plan.ps1` los mueve sin calcular su SHA‑256.
### Cambiado
- Tarea horaria: aviso «VIGILANTE CON ERRORES» cuando las tres últimas pasadas terminan en `FIN_ERROR` (antes solo se avisaba si dejaba de latir), y criterio para clasificar archivos nativos de Google.
- Pruebas: `prueba9.ps1` (5 casos). Total: 120.

## [1.11] — 2026-10-07
### Añadido
- `config_plataforma.csv` con `RaizDocumental` (por defecto `G:\Mi unidad\DESCARGAS`), `CarpetaEntrada` (por defecto `INPUT`) y `CarpetaSolicitudes` (por defecto `%DESCARGAS_NAVEGADOR%`, la carpeta Descargas de Windows). Herramienta `Configurar_Plataforma.ps1` y lanzador `CONFIGURAR_PLATAFORMA.bat`.
- Recogida de solicitudes del panel desde la carpeta de descargas del navegador (y cualquier otra configurada). Las solicitudes ya procesadas que reaparecen se archivan en `procesadas\repetidas`.
- M15 `Copia_Verificada.ps1`: copia incremental sin espejo, verificación SHA‑256, versiones `__v<fecha>`, rechazo de destinos sincronizados y bloqueo durante alertas M16. El vigilante la lanza una vez al día.
- M14 `src/m14/m14_extraer.py` y `m14_siguiente_lote.py`: índice de entidades por reglas, sin datos personales.
- `estado_plataforma.json` en cada pasada; `vigilante_sin_raiz.txt` cuando la raíz no está disponible.
- Repositorio, pruebas portables (`tests/run_all.sh`), documentación y ADR.
### Cambiado
- La carpeta de entrada `nuevos` pasa a llamarse `INPUT`. El vigilante la migra solo (fase ENTRADA, `entrada_historial.txt`) y `Aplicar_Plan.ps1` sigue aplicando planes con el nombre antiguo.
- M16 excluye la carpeta de entrada configurada y sus nombres anteriores del recuento de cambios masivos.
- El panel muestra en el diálogo de confirmación las carpetas de recogida vigentes.
- `VersionSkill` del manifiesto: `1.11` y `1.11-sha-diferido`.

## [1.10.3] — 2026-10-06
- Panel: textos del original contenidos en su columna; huella abreviada (12 + 12 cifras) en el original y en cada copia, a 1 cm del estado.

## [1.10.2] — 2026-10-06
- Panel con HTML fijo y datos en tres archivos rotatorios `_panel\datos_1..3.js`; generación en proceso aparte con tiempo máximo de 300 s. Corrige el bloqueo del panel y los `.tmp` huérfanos.

## [1.10.1] — 2026-10-06
- `Aplicar_Plan.ps1`: presupuesto de 12 min con plan de resto; hash diferido para archivos de más de 1 GB.

## [1.10] — 2026-10-05
- Panel de duplicados (M20) y borrado verificado a petición del usuario; área `11_ESCRITOS_PROPIOS`.

## [1.9.2] — 2026-10-05
- Presupuesto de la fase RAÍZ, manifiesto fila a fila, fase CONCILIAR y rotación del M16.

## [1.9.1] — 2026-10-05
- Clasificación por bloques (tarea horaria); registro fila a fila en `Aplicar_Plan.ps1`.

## [1.9] — 2026-10-04
- Bloqueo con PID y fase, latido por pasada, M16 con presupuesto, tarea con batería.

## [1.8] — 2026-10-04
- Área `07_DOCUMENTACION` con taxonomía UNESCO.

## [1.0–1.7] — 2026-10-03/04
- Procedimiento base, huella ZIP, vigilante, módulos M1–M19 y M16 implantado.
