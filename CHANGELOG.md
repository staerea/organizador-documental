# Historial de versiones

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/); versiones `MAYOR.MENOR.PARCHE`.

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
