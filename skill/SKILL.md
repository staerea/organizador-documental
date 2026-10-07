---
name: "organizador-documental"
description: "Ordena, deduplica (SHA-256), clasifica por áreas y renombra por contenido los archivos nuevos de una carpeta raíz ya organizada (por defecto G:\\Mi unidad\\DESCARGAS, entrada INPUT; rutas configurables), con manifiesto, vigilante automático, panel de duplicados con borrado verificado a petición del usuario, índice de entidades, copia verificada y repositorio versionado."
---

# Organizador documental (v1.11)

Skill para mantener ordenada una carpeta raíz del equipo del usuario (caso de referencia: `G:\Mi unidad\DESCARGAS`, sincronizada con Google Drive). Reproduce el procedimiento validado en la sesión del 03‑10‑2026: inventario, detección de duplicados por SHA‑256, clasificación por áreas, renombrado contextual según el contenido, ejecución reversible y verificación.

## Principios no negociables

1. **No se borra nunca ningún documento por iniciativa del sistema.** Solo se crean carpetas, se mueve y se renombra. Los duplicados se apartan a `_DUPLICADOS_REVISAR\<área>\` con sufijo `__COPIA_n`; borrarlos lo decide el usuario.
   - **Única excepción (v1.10):** el usuario puede pedir el borrado de copias desde el panel `_DUPLICADOS_REVISAR\PANEL_DUPLICADOS.html` (M20). El vigilante solo borra una copia si está **dentro** de `_DUPLICADOS_REVISAR`, su original sigue **fuera** de esa carpeta y el contenido es idéntico (SHA‑256 recalculado en ese momento, o huella ZIP). En Google Drive para escritorio el borrado va a la papelera de Drive (recuperable 30 días). Cada decisión queda en el registro, en el resultado de la solicitud y en el manifiesto (`BORRADO_POR_USUARIO`). Claude nunca crea solicitudes de borrado por su cuenta.
2. **Todo es reversible.** Cada ejecución deja `_ORGANIZACION\registro_<fecha>.csv`, que `Deshacer.ps1` usa para restaurar.
3. **Primero se simula.** Los scripts simulan por defecto; solo actúan con `-Ejecutar`.
4. **Duplicado = SHA‑256 idéntico**, nunca el nombre ni el tamaño. Antes de apartarlo se vuelve a verificar el hash del duplicado y del original. Mismo tamaño con hash distinto = versiones distintas: se conservan todas y se numeran `_vN`.
   - **Excepción para los ZIP (v1.1):** dos `.zip` con los mismos archivos dentro son duplicados aunque su SHA‑256 difiera porque se recomprimieron en otra fecha, con otro orden o con otra compresión. Se detecta con la **huella de contenido**: el SHA‑256 de la lista ordenada `ruta|tamaño|CRC32` de sus archivos, leída del directorio central sin descomprimir.
     - Se marcan con `Accion=DUPLICADO_ZIP` y se apartan como `__COPIA_CONTENIDO_n`. Antes de moverlos, el script recalcula la huella del duplicado y del original.
     - No se indexa el contenido completo de cada ZIP: solo la huella.
     - Se ignoran las entradas de carpeta y `__MACOSX`.
     - Los ZIP cifrados, dañados, `.7z` y `.rar` no tienen huella y se tratan por SHA‑256.
5. **La taxonomía la fija la raíz.** Las áreas de destino son las carpetas que ya existen en la raíz, las mismas que contienen la carpeta de entrada: `01_STAEREA_PROYECTOS`, `02_STAEREA_ADMIN`, `03_FORMACION_NORMATIVA` (solo normativa desde v1.8), `05_IA_PROMPTS_AGENTES`, `06_DESARROLLO_SOFTWARE`, `07_DOCUMENTACION` (v1.8), `08_ASESORIA_LABORAL_FISCAL`, `09_PERSONAL_SENSIBLE`, `10_MULTIMEDIA`, `11_ESCRITOS_PROPIOS` (v1.10: ensayos, capítulos, libros, artículos e informes de autoría propia no vinculados a la actividad profesional; no van a `07_DOCUMENTACION`) y `99_REVISAR_SIN_CLASIFICAR`, con sus subcarpetas. Instaladores (`.exe`, `.msi`, `.apk`) y archivos asociados a licencias de software → `06_DESARROLLO_SOFTWARE\Instaladores`; imágenes generadas con IA → `10_MULTIMEDIA\Imagenes_IA`. Antes de cada ejecución se relistan. Una subcarpeta nueva solo se crea si ninguna existente encaja, y se informa de ello. `04_PAPERS_INVESTIGACION` queda **en desuso** desde v1.8: su contenido se migró a `07_DOCUMENTACION`; la carpeta no se borra, pero no recibe archivos nuevos.
6. **No se renombran carpetas de proyectos de software** (ODIP, REQUEST_AGENT, visores, etc.) ni el contenido de las carpetas que se mueven como bloque: romperían rutas internas.

## Alcance según la versión

- **v1 (base):** los archivos a procesar están en la carpeta de entrada, dentro de la raíz (`INPUT` desde v1.11; antes `nuevos`). Lo ya organizado no se toca, salvo para compararlo y detectar duplicados.
- **v1.2 (automatización):** un vigilante local (`Vigilante_Raiz.ps1`, tarea de Windows cada 10 min) detecta lo que aparece suelto en la raíz, aparta en el acto los duplicados exactos y de contenido ZIP contra el manifiesto, encola el resto en `INPUT` y aplica los planes que deje la tarea diaria de Claude en `_ORGANIZACION\planes_pendientes`. Ver la sección «Modo automático».
- **v1.11 (07‑10‑2026, a petición del usuario):**
  - **Rutas configurables** en `_ORGANIZACION\config_plataforma.csv`, editable con `CONFIGURAR_PLATAFORMA.bat`: `RaizDocumental` (por defecto `G:\Mi unidad\DESCARGAS`), `CarpetaEntrada` (por defecto `INPUT`) y `CarpetaSolicitudes` (por defecto `%DESCARGAS_NAVEGADOR%`, la carpeta Descargas de Windows que usan los navegadores; admite varias separadas por `|`). Ver «Configuración de la plataforma».
  - **`nuevos` pasa a llamarse `INPUT`.** El vigilante migra solo la carpeta (la renombra o traslada su contenido sin pisar nada), anota los nombres usados en `entrada_historial.txt` y `Aplicar_Plan.ps1` sigue aplicando los planes que citen el nombre antiguo. Cualquier cambio posterior del nombre se migra igual.
  - **Recogida de solicitudes del panel** también desde la carpeta de descargas del navegador; una solicitud ya procesada que reaparece se archiva en `procesadas\repetidas` sin repetirla. Motivo: el 06‑10‑2026 dieciocho solicitudes quedaron en `Descargas` sin llegar al vigilante.
  - **M15 implantado** (`Copia_Verificada.ps1`), **M14 implantado** (extractor por reglas en el repositorio), control de salud en la tarea horaria, raíz no disponible tratada sin error (`vigilante_sin_raiz.txt`) y estado de cada pasada en `estado_plataforma.json`.
  - **Repositorio versionado** `staerea/organizador-documental` (GitHub, privado): código fuente, distribución, pruebas, documentación y este skill. Los anexos de código de versiones anteriores se sustituyen por el repositorio (ver «Repositorio y despliegue»).
- **v1.10.1–v1.10.3 (06‑10‑2026):** `Aplicar_Plan.ps1` con presupuesto de 12 min (`<plan>_resto_<hora>.csv`) y hash diferido en archivos de más de 1 GB; panel con datos en tres archivos rotatorios `_panel\datos_1..3.js`, HTML fijo y generación en proceso aparte con tiempo máximo (incidente de bloqueo del 06‑10‑2026); textos del original contenidos en su columna y huella abreviada (12 primeras + 12 últimas cifras) en original y copias.
- **v1.10 (panel de duplicados, 05‑10‑2026):** `Generar_Panel_Duplicados.ps1`  crea `_DUPLICADOS_REVISAR\PANEL_DUPLICADOS.html`, con un registro por grupo (documento clasificado que se conserva + todas sus copias), miniaturas, ubicación, estado de verificación y marcado para borrar, incluido el marcado de todas las copias de un grupo a la vez. El panel no borra: descarga `SOLICITUD_BORRADO_DUPLICADOS_<fecha>.csv`, que el vigilante verifica y ejecuta (fase BORRADOS). Ver M20.
- **v1.9.2 (05‑10‑2026):** la fase RAIZ del vigilante tiene presupuesto (15 min) y sigue en la pasada siguiente; los duplicados apartados se anotan en el manifiesto fila a fila; la fase CONCILIAR repone las filas que falten según el registro del mes; el M16 rota el orden de áreas y anota la carpeta correcta cuando se agota el presupuesto. Motivo: a las 22:32 del 05‑10‑2026 reaparecieron en la raíz más de 700 archivos (88 % idénticos a documentos ya clasificados) y una pasada larga podía cortarse a los 30 min perdiendo filas del manifiesto.
- **v1.9.1 (05‑10‑2026):** clasificación **por bloques** (tarea horaria de Claude, ≤ 60 elementos por bloque); `Aplicar_Plan.ps1` escribe registro y manifiesto fila a fila y, en `DUPLICADO` sin SHA en el plan, compara los hashes de duplicado y original en el equipo; el vigilante aplica planes durante 12 min como máximo por pasada; M16 con enumeración en *streaming* para que el presupuesto corte de verdad; lista de espera `_ORGANIZACION\nuevos_en_espera.txt` para lo que requiere decisión del usuario.
- **v1.9 (fiabilidad del vigilante):** bloqueo con PID y fase, recuperación de bloqueos huérfanos a los 35 min (o al momento si el proceso ya no existe), registro de latido por pasada, M16 con presupuesto de tiempo y recorrido de `06_DESARROLLO_SOFTWARE` solo cada hora, y tarea de Windows que arranca y continúa con batería. Motivo: el 04‑10‑2026 una pasada iniciada a las 18:48 no terminó, dejó el bloqueo y no hubo más pasadas; el plan de correcciones quedó sin aplicar.
- **v1.8 (área de documentación):** nueva área `07_DOCUMENTACION`, subdividida por campos de la Nomenclatura Internacional UNESCO para Ciencia y Tecnología (códigos de 2 dígitos); `03_FORMACION_NORMATIVA` queda solo para normativa. Ver «Clasificación por áreas». Migración inicial: plan `plan_20261004_1630_documentacion.csv` (75 archivos, aplicado por el vigilante el 04‑10‑2026: 75 MOVIDO, registro `registro_20261004_161221.csv`, reversible con `Deshacer.ps1`).
- **v1.7 (módulos avanzados; M16 implantado):** diecinueve módulos (M1–M19; desde v1.10, veinte con el M20, que no depende de `config_modulos.csv`), con interruptores de activación en `_ORGANIZACION\config_modulos.csv`, que se activan a petición del usuario o desde la tarea diaria sin cambiar el flujo base. **Regla de mantenimiento: al actualizar el skill no se elimina ningún módulo**, aunque no figure en una lista posterior del usuario; solo se añaden o se mejoran. Ver la sección «Módulos avanzados».
- **Preparado para v2 (marcador):** el marcador de "ya clasificado" es `_ORGANIZACION\manifiesto_documental.csv`. Cada archivo procesado queda registrado con ruta, SHA‑256, tamaño, fecha de modificación, área, estado, nombre original, fecha y versión del skill. Un archivo **no clasificado** es cualquiera que no esté en el manifiesto, o cuyo tamaño o fecha haya cambiado. El inventario ya los reporta en la columna `EnManifiesto` y en el contador "Sin clasificar fuera de entrada". En v2 basta con tratar también esas filas como entrada.
  - No se usan flujos alternativos NTFS ni etiquetas en el nombre como marcador, porque Google Drive no los conserva de forma fiable. El hash en el manifiesto sobrevive a movimientos y renombrados hechos por el usuario.
- **Primera ejecución en una raíz ya ordenada:** lanzar el inventario con `-Sembrar`, que registra como `HEREDADO` todo lo que ya está en carpetas de área. Antes de sembrar, mover a `_ORGANIZACION` los scripts, planes y registros que haya sueltos en la raíz.

## Entorno y herramientas

- Las carpetas del equipo se alcanzan con las herramientas `mcp__remote-devices__*`. Si `device_bash` funciona, los scripts se ejecutan con él. **Si falla ("Workspace unavailable"), lo que ocurrió en la sesión de referencia**, el procedimiento es:
  1. Leer con `device_list_dir`.
  2. Traer al contenedor solo lo imprescindible con `device_stage_files`: como máximo 50 archivos y 500 MB por llamada.
  3. Generar el plan y los scripts en el contenedor.
  4. Escribirlos en la raíz con `device_commit_files`, usando `force:true` si sustituyen una versión anterior propia.
  5. Pedir al usuario que haga **doble clic** en el `.bat` (o, en modo automático, dejar el plan en `planes_pendientes`).
- **Nunca** lanzar los scripts con uso del ordenador: el Explorador solo se concede con permiso de clic, y ejecutar un `.bat` así equivale a saltarse esa restricción. Lo correcto es dejar el `.bat` preparado y pedírselo al usuario.
- **Comprobar después de cada `device_commit_files`** (con `device_list_dir`, mirando tamaño y fecha) que el archivo en el equipo es la versión nueva. En la sesión de referencia el usuario ejecutó una versión anterior del script y no se aplicó el renombrado.
- **Cada versión de un script se sube desde un archivo de salida con nombre único**, por ejemplo `outputs/org_v11/Aplicar_Plan_v11.ps1`, que se escribe en el equipo como `Aplicar_Plan.ps1`. Si se reutiliza el mismo nombre de salida, `device_commit_files` puede escribir una versión anterior en caché. Esto ocurrió dos veces en la sesión de referencia. Después de cada subida hay que comprobar el **tamaño** con `device_list_dir`.
- Los scripts se escriben en UTF‑8 **con BOM** y con saltos de línea CRLF, para que funcionen en Windows PowerShell 5.1. Antes de entregarlos se prueban sobre una réplica con PowerShell 7: se descarga de los releases de PowerShell en GitHub si no está.
- **Desde v1.11 el código vive en el repositorio** (`src/` editable, `dist/` generado con `tools/build.py`, `tests/`). Nunca se edita a mano un script desplegado: se cambia `src/`, se reconstruye, se ejecutan todas las pruebas y se despliega `dist/` (ver «Repositorio y despliegue»).
- Si la raíz no aparece (`device_list_dir` dice que no existe), lo habitual es que Google Drive para escritorio esté cerrado o reiniciándose: avisar al usuario y no desplegar hasta que vuelva.

## Flujo de trabajo

Crear una lista de tareas con estas fases y marcarlas al completarlas.

### 1. Inventario (sin cambios)
1. Ejecutar `device_list_dir` sobre la raíz (no recursivo) para descubrir las áreas, y después en recursivo sobre cada área, salvo `06_DESARROLLO_SOFTWARE`, que es enorme. Si la salida supera el límite, se guarda en archivo: leerla con Python, no paginarla en la conversación.
2. Si existe `_ORGANIZACION\Inventariar_Raiz.ps1`, pedir al usuario que ejecute `INVENTARIAR.bat`, o lanzarlo con `device_bash`. El script calcula **en local** el SHA‑256 de toda la raíz, reutilizando el hash del manifiesto si nada ha cambiado. Después basta con traer el `inventario_<fecha>.csv`, que pesa pocos KB, en lugar de gigas de archivos.
3. Si el script no existe todavía, crear la carpeta `_ORGANIZACION` con los scripts del anexo y pedir la primera ejecución con `-Sembrar`.

### 2. Duplicados
- Agrupar por SHA‑256: los archivos de `INPUT` entre sí, y los de `INPUT` contra el resto de la raíz.
- Elección del original que se conserva:
  1. El que ya está clasificado.
  2. Si no, el nombre sin «(n)».
  3. Si no, el nombre descriptivo frente al genérico («Documento», «ChatGPT Image», hashes o UUID).
  4. Si no, el más antiguo.
- Mismo tamaño y hash distinto: son versiones, se conservan todas.
- **ZIP:** agrupar también por `HuellaZip`, que aparece en el inventario, en `_ORGANIZACION\huellas_zip.csv` (en caché por SHA‑256) y en `zip_mismo_contenido_<fecha>.csv`. Si la huella es igual y el SHA‑256 distinto, es un `DUPLICADO_ZIP`. Para elegir el original se aplican las mismas reglas que al resto de duplicados.
- Un ZIP y la carpeta que resulta de descomprimirlo **no** se consideran duplicados en esta versión. Si se detecta un caso evidente (mismo nombre base), se informa.
- Detectar también las versiones casi idénticas: misma familia de nombre con `v1`, `final`, `signed`, `_corregido`, etc. Se informan, pero no se tocan.

### 3. Lectura de contenido (para clasificar y nombrar)
- **PDF:** `pdftotext -l 2` sobre los documentos traídos al contenedor. Si no hay texto, es un escaneo: se nombra de forma genérica y se avisa.
- **DOCX:** leer `word/document.xml`.
- **Imágenes:** hojas de contacto con PIL (20 miniaturas numeradas por hoja) y revisión visual con `Read`.
- **ZIP:** `unzip -l`.
- **Texto, MD, CSV y JSON:** las primeras líneas.
- Archivos de más de 400 MB: no se pueden traer; se nombran por los metadatos y van a `99_REVISAR_SIN_CLASIFICAR`.
- El contenido manda sobre el nombre. Casos reales de la sesión de referencia:
  - «Formación específica del puesto» eran certificados AESA.
  - «Presupuesto vuelo multiespectral» era un anexo de Llerena.
  - «Memoria Tecnica.pdf» tenía 0 bytes.

### 4. Clasificación por áreas
- `01_STAEREA_PROYECTOS\<Proyecto>`: Llerena_Pallares, Agrodato, Condado_Alhama, Puertollano, Primaflor, Mar_Menor, Tactical_UAS_Aphid, OSAVI_Lechuga_Kriging, Parcelarios_Auditoria, Herbicida_NDVI, Alcazar_MDT, Superficies_voladas, STSENS_Golf, Vigilancia_Drone_in_a_Box. Lo comercial o técnico sin proyecto va a `Comercial_y_Tecnico_General`.
- `02_STAEREA_ADMIN\…`: AESA_Operador_UAS, PRL_CAE_Coordinacion, Seguros, Facturas_Recibos, Hacienda_TGSS, Notificaciones_DEHU, Bancos_Movimientos.
- `03_FORMACION_NORMATIVA`: **solo normativa** (v1.8): leyes, reales decretos, decretos autonómicos, reglamentos y directivas UE, órdenes y resoluciones del BOE/DOUE/boletines autonómicos, en su texto oficial. Las guías, circulares, infografías o resúmenes que **explican** una norma son documentación (`07_DOCUMENTACION\56_…`). Regla de alcance aprobada por el usuario: la normativa que ya está dentro de un proyecto (`01_…`) no se extrae.
- `07_DOCUMENTACION\<CC_CAMPO>[\<Coleccion>]` (v1.8): documentación de referencia de terceros o de consulta general: manuales y fichas técnicas de equipos, temarios y guías de formación, manuales tributarios, trabajos de grado y posgrado (TFG, TFM, tesis), papers, artículos científicos, revisiones, informes de investigación, revistas científicas y prensa sectorial, libros y apuntes.
  - **No es documentación** (se queda en su área): los entregables propios de STAEREA o de un cliente (informes técnicos, memorias, presentaciones, manuales internos o de procedimientos de la empresa, planes PRL/CAE), los expedientes, formularios de inscripción y convocatorias de eventos (→ `10_MULTIMEDIA\Eventos`), y los prompts o directivas para agentes (→ `05_IA_PROMPTS_AGENTES`).
  - **Taxonomía estricta UNESCO (elegida por el usuario):** las subcarpetas son los campos de 2 dígitos, con nombre `CC_NOMBRE`. Se crean solo cuando hacen falta: `11_LOGICA`, `12_MATEMATICAS`, `21_ASTRONOMIA_Y_ASTROFISICA`, `22_FISICA`, `23_QUIMICA`, `24_CIENCIAS_DE_LA_VIDA`, `25_CIENCIAS_TIERRA_Y_ESPACIO`, `31_CIENCIAS_AGRARIAS`, `32_CIENCIAS_MEDICAS`, `33_CIENCIAS_TECNOLOGICAS`, `51_ANTROPOLOGIA`, `52_DEMOGRAFIA`, `53_CIENCIAS_ECONOMICAS`, `54_GEOGRAFIA`, `55_HISTORIA`, `56_CIENCIAS_JURIDICAS_Y_DERECHO`, `57_LINGUISTICA`, `58_PEDAGOGIA`, `59_CIENCIA_POLITICA`, `61_PSICOLOGIA`, `62_CIENCIAS_ARTES_Y_LETRAS`, `63_SOCIOLOGIA`, `71_ETICA`, `72_FILOSOFIA`.
  - El código de 4 o 6 dígitos, cuando se puede determinar, se anota en el manifiesto en la columna `Area` como `07_DOCUMENTACION|UNESCO_<código>` (p. ej. `UNESCO_1203.04`). No se crean carpetas de 4 dígitos salvo petición del usuario.
  - **Regla de asignación:** campo de la **materia de estudio** del documento, no de la herramienta. Un trabajo de IA aplicada a cultivos va a 31; uno sobre métodos de IA, a 12 (1203.04).
  - Criterios fijados en la migración inicial (para mantener coherencia):
    - IA y aprendizaje automático generales → `12` (1203.04 Inteligencia artificial).
    - GeoAI, SIG y geocomputación general → `25` (2505 Geografía). La Nomenclatura no tiene código específico de SIG: se informa de ello al usuario si pregunta.
    - GeoAI urbana o de geografía humana → `54` (5403 Geografía humana).
    - Teledetección y fotogrametría sin cultivo concreto, y la Revista de Teledetección de la AET → `25` (2506.16 Teledetección; 2504.04 Fotogrametría geodésica). Edafología 2511, hidrología 2508, ciencias del espacio 2512.
    - Teledetección o UAV aplicados a cultivos, agricultura de precisión y prensa agrícola → `31` (3103 Agronomía; 3107 Horticultura).
    - Drones/UAS (temarios AESA, manuales de vuelo y de equipos) → `33` (3301 Ingeniería y tecnología aeronáuticas); fichas de sensores e instrumentos → 3311; energía → 3322.
    - Manuales tributarios (AEAT) y contables → `53` (5301 Política fiscal y hacienda pública).
    - Documentación explicativa de normas laborales o jurídicas → `56`.
    - IA en educación → `58` (5801).
  - Colecciones con más de 4 documentos homogéneos van en subcarpeta propia dentro del campo: `Revista_Teledeteccion_AET`, `Prensa_sectorial`, `AEAT_Manuales_Renta`, `AESA_Formacion_UAS`, `Manuales_Equipos`, `Manual_Errores_Contables_Riesgos_Fiscales`.
  - Fuente de la nomenclatura: Nomenclatura Internacional de la UNESCO para los campos de Ciencia y Tecnología (versión publicada por el Ministerio de Ciencia y en tablas universitarias, p. ej. Universidad de Murcia).
- `05_IA_PROMPTS_AGENTES`: prompts, agentes y skills.
- `06_DESARROLLO_SOFTWARE`: código, dashboards, firmware, proyectos.
- `08_ASESORIA_LABORAL_FISCAL\…`: General, Catastro_Registro, `Expediente_<Tipo>_<Apellidos>` (un expediente por cliente o caso).
- `09_PERSONAL_SENSIBLE`: identificación, salud, banca, vehículos, vida laboral, credenciales.
- `10_MULTIMEDIA\…`: Marca_Omnia, Infografias_*, Ilustraciones_*, Imagenes_Satelite, Fotos_Equipos, Eventos, Logos_Terceros, podcasts y grabaciones.
- `99_REVISAR_SIN_CLASIFICAR`: lo no identificable con seguridad.

### 5. Convención de nombres
- El formato es `<Contexto>_<Tipo>_<Descripcion>[_<Fecha>][_vN|_firmado|_borrador].<ext>`.
  - **Contexto:** prefijo de proyecto (`Llerena_`, `Agrodato_`, `Condado_Alhama_`, `Tactical_UAS_Aphid_`, `OSAVI_Lechuga_`…), de organismo (`AEAT_`, `TGSS_`, `INSS_`, `AESA_`, `DGT_`, `CARM_`) o de tipo (`Paper_`, `Factura_`, `Recibo_`, `Seguro_`, `PRL_`, `CAE_`, `IVGA_`, `Pericial_`, `Agente_<Familia>_vX.Y.Z_`).
  - **Fechas** en ISO, `AAAA-MM-DD` o `AAAA-MM`.
  - **Versiones:** `_v2`, `_v3`… en lugar de «(1)», «(2)».
  - **Duplicados:** `<nombre del original>__COPIA_n`.
  - **Papers:** `Paper_<PrimerAutor>_<Año>_<Revista>_<Tema>`; editoriales de número especial `Editorial_<PrimerAutor>_<Año>_<Revista>_<Tema>`; preprints `Preprint_<PrimerAutor>_<Año>_arXiv_<Tema>`; recopilaciones sin revisión por pares `Recopilacion_<Autor>_<Tema>`, a partir de la cabecera del PDF; los nombres del tipo `Paper_JAG_2022_v112_102936` o `1-s2.0-…-main` se sustituyen por autor y tema. Trabajos académicos: `TFG_`, `TFM_` o `Tesis_<Autor>_<Año>_<Universidad>_<Tema>`.
  - **Expedientes clínicos o administrativos:** `<Prefijo>_<TipoInforme>_<Servicio>_<Fecha>`.
- **Datos sensibles:** no se ponen en el nombre diagnósticos, números de DNI, IBAN ni importes de terceros. Las fotos de documentos personales se nombran de forma genérica (`Foto_documento_personal_<fecha>`).
- **Reglas técnicas:**
  - Sin `< > : " / \ | ? *` ni punto o espacio final. Espacios, «—», «+», «(», «)» y comas se convierten en `_`.
  - **Conservar siempre la extensión real** con `os.path.splitext`, sin limitar su longitud. En la sesión de referencia, `.geojson` se perdió por limitar la extensión a 6 caracteres: después de construir el plan, comprobar que cada nombre nuevo termina en la extensión original.
  - Resolver colisiones en el plan (`_a`, `_b`); el script añade además `[orgN]` si encuentra un choque en el disco.

### 6. Plan, entrega y ejecución
1. Generar `_ORGANIZACION\plan_<fecha>.csv`, separado por `;`, en UTF‑8 con BOM, con las columnas `Origen;Tipo;Destino;NuevoNombre;Accion;OriginalConservado;SHA256;Area`.
   - Las rutas van relativas a la raíz y con `\`.
   - `Accion` puede ser `MOVER`, `DUPLICADO` o `DUPLICADO_ZIP`.
   - En `DUPLICADO_ZIP` la columna `SHA256` va vacía; el script verifica la huella.
   - Las carpetas de entrada que sean proyectos se mueven como bloque (`Tipo=carpeta`).
2. Validar el plan antes de entregarlo:
   - Pares destino + nombre únicos.
   - Sin caracteres inválidos.
   - Extensiones conservadas.
   - Todos los `OriginalConservado` existen.
3. Probar el plan con `pwsh` sobre una réplica del árbol, construida con archivos vacíos o copias traídas al contenedor: simulación, ejecución y reversión, contando que no se pierde ningún archivo.
4. Escribir en la raíz, con `device_commit_files`, el plan, los scripts y `APLICAR.bat`. El `.bat` hace `cd /d "%~dp0"` y llama a `_ORGANIZACION\Aplicar_Plan.ps1 -Plan <plan> -Ejecutar` con `-ExecutionPolicy Bypass`, `chcp 65001` y `pause`.
5. Pedir al usuario el doble clic, o ejecutarlo con `device_bash` si está disponible. En modo automático, escribir el plan en `_ORGANIZACION\planes_pendientes\` en lugar de crear `APLICAR.bat`.

### 7. Verificación e informe
- Traer al contenedor el `registro_<fecha>.csv` y contar los estados: `MOVIDO`, `DUPLICADO_VERIFICADO`, `DUPLICADO_ZIP_VERIFICADO`, `MOVIDO_HASH_NO_VERIFICADO`, `MOVIDO_HUELLA_NO_VERIFICADA`, `NO_ENCONTRADO`, `ERROR`, `[orgN]`.
- Listar las áreas afectadas y comprobar en una muestra que los nombres y las extensiones son correctos.
- Informe final breve:
  - Cuántos archivos se han procesado, cuántos duplicados se han apartado y cuántos MB ocupan.
  - Qué ha quedado en `99_`.
  - Avisos: credenciales en claro (`recovery-codes`), datos de salud de terceros, archivos vacíos, ZIP enormes sin identificar.
- No recapitular los pasos.

## Modo automático (v1.2)

Arquitectura en dos piezas, porque `device_bash` puede no estar disponible y el uso del ordenador no debe lanzar scripts:

1. **Vigilante local** (`_ORGANIZACION\Vigilante_Raiz.ps1`, Anexo E), registrado por `INSTALAR_VIGILANTE.bat` como tarea `Organizador_DESCARGAS_Vigilante` (cada 10 min, oculta, `IgnoreNew`, límite 30 min; solo con la sesión de Windows iniciada; desde v1.9 también con batería, `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries`, porque la configuración por defecto de Windows no arranca la tarea, o la corta, en un portátil desenchufado). En cada pasada:
   - Si existe `_ORGANIZACION\vigilante.pausa` (creado por el M16), no hace nada hasta que el usuario ejecute `REANUDAR_VIGILANTE.bat`.
   - Bloqueo `vigilante.lock` con contenido `fecha|PID|fase` (v1.9). Se considera huérfano si el proceso que lo creó ya no existe o a los 35 min (la tarea se corta a los 30); un bloqueo antiguo sin PID se respeta solo 35 min. Si el proceso sigue vivo pasado ese tiempo y su línea de órdenes es la del vigilante, se detiene; nunca se detiene un proceso no verificado.
   - **Latido (v1.9):** cada pasada anexa una fila a `_ORGANIZACION\vigilante_latido_<AAAAMM>.csv` (Fecha;Evento;Fase;DuracionSeg;PID;Detalle), con eventos `FIN_OK` (movidos, planes, `raiz_pendientes`, `conciliados`, `borrados`), `FIN_ERROR`, `FIN_ALERTA_M16`, `SALTO_EN_CURSO`, `SALTO_PAUSA_M16`, `BLOQUEO_HUERFANO_RECUPERADO`, `PROCESO_COLGADO_DETENIDO`, `PLANES_APLAZADOS` (v1.9.1), `RAIZ_APLAZADA`, `CONCILIADO`, `CONCILIAR_APLAZADA` (v1.9.2), `BORRADOS`, `BORRADOS_APLAZADOS` y `PANEL_ACTUALIZADO` (v1.10). Si una pasada se cuelga, la fase queda en el propio `vigilante.lock` (INICIO, M16_ALERTA, MANIFIESTO, CONCILIAR, BORRADOS, RAIZ, PLANES, PANEL, FIN).
   - **Presupuestos por pasada (v1.9.1–v1.10)**, para no rozar el corte de 30 min de la tarea: M16 120 s; CONCILIAR 180 s; BORRADOS 6 min; RAIZ hasta el minuto 15 de la pasada (lo que no da tiempo se cuenta como `raiz_pendientes` y sigue en la siguiente); PLANES, nuevos planes solo hasta el minuto 12 (siempre se aplica al menos uno); PANEL solo si la pasada lleva menos de 24 min. Una llegada masiva de 724 elementos se completó en una pasada de 19 min (05‑10‑2026).
   - **Conciliación (v1.9.2):** los duplicados apartados se anotan en el manifiesto en el momento (antes, al final de la pasada). Si aun así una pasada se corta, la fase CONCILIAR repone, a partir de `vigilante_<AAAAMM>.csv`, las filas `DUPLICADO*` cuyo destino existe y no figura en el manifiesto (`VersionSkill=1.9.2-conciliacion`).
   - **Borrado verificado (v1.10, M20):** recoge `SOLICITUD_BORRADO_DUPLICADOS_*.csv` de la raíz (o de la entrada), lo traslada a `_ORGANIZACION\borrados_solicitudes\` y, fila a fila, comprueba ruta de la copia dentro de `_DUPLICADOS_REVISAR` (sin `..`), original fuera de `_DUPLICADOS_REVISAR` y `_ORGANIZACION`, existencia de ambos y contenido idéntico; solo entonces borra la copia. Estados: `BORRADO_VERIFICADO`, `NO_BORRADO`, `NO_BORRADO_YA_NO_EXISTE`, `NO_BORRADO_ORIGINAL_AUSENTE`, `NO_BORRADO_CONTENIDO_DISTINTO`, `NO_BORRADO_ERROR`. El resultado se escribe en `resultado_<solicitud>.csv` y ambos pasan a `borrados_solicitudes\procesadas\`; si se agota el presupuesto, la solicitud se reanuda en la pasada siguiente sin repetir filas.
   - **Panel (v1.10, M20):** al final de la pasada regenera `_DUPLICADOS_REVISAR\PANEL_DUPLICADOS.html` si hubo duplicados, planes, conciliaciones o borrados, si no existe o si tiene más de 60 min.
   - **Recogida de solicitudes (v1.11):** de la raíz, de la entrada y de las carpetas de `CarpetaSolicitudes` (por defecto, Descargas del navegador). Una solicitud cuyo nombre y tamaño ya constan como recibidos se archiva en `borrados_solicitudes\procesadas\repetidas\` (`SOLICITUD_REPETIDA_ARCHIVADA`).
   - **Migración de la entrada (v1.11, fase ENTRADA):** si existe una carpeta con un nombre anterior de la entrada (`nuevos` o los de `entrada_historial.txt`), se renombra a la actual o, si ya existe, se traslada su contenido (`[orgN]` ante colisión) y se elimina la carpeta vacía; latido `ENTRADA_MIGRADA`.
   - **Raíz no disponible (v1.11):** si la raíz configurada no contiene `_ORGANIZACION` (Drive sin montar, ruta errónea), el vigilante anota la incidencia en `vigilante_sin_raiz.txt` junto a los scripts y termina sin error.
   - **Estado (v1.11):** al terminar escribe `_ORGANIZACION\estado_plataforma.json` (versión, última pasada, raíz, entrada, carpetas de recogida y recuentos).
   - **Diagnóstico:** si `planes_pendientes` no se vacía en 15 min, mirar el latido y el `vigilante.lock` (fecha y fase). Sin filas nuevas en el latido, la tarea no se está lanzando: revisar en el Programador de tareas su estado, «Último resultado» y las condiciones de energía, y volver a ejecutar `INSTALAR_VIGILANTE.bat`.
   - (v1.7) Si el M16 está activo, ejecuta antes `Verificar_Integridad.ps1 -Modo Alerta`; si hay alerta, se pausa y termina. Una vez al día lanza en segundo plano `Verificar_Integridad.ps1 -Modo Muestra`.
   - Ignora en la raíz: **carpetas** de área o de control (`NN_*`, `_*`, `99_*`), `INPUT`, `desktop.ini`, `thumbs.db`, `~$*`, descargas en curso (`.crdownload`, `.part`, `.partial`, `.download`, `.tmp`, `.opdownload`), los `.bat` propios, `ALERTA_INTEGRIDAD.txt`, las solicitudes `SOLICITUD_BORRADO_DUPLICADOS_*.csv` (las atiende la fase BORRADOS) y lo listado en `_ORGANIZACION\excluir_raiz.txt`.
   - **Corrección v1.7:** los patrones `NN_*` y `_*` se aplican solo a carpetas. Hasta la v1.6 también excluían **archivos** sueltos cuyo nombre empezaba por `_` o `NN_` (caso real: `_Estado Hídrico (NDMI)…pdf` y `_Vigor Vegetativo (NDVI)…zip` quedaban sin procesar).
   - Solo actúa sobre elementos **estables**: más de 120 s sin modificarse y que se puedan abrir en exclusiva (en carpetas, la fecha más reciente de su contenido).
   - SHA‑256 idéntico a un archivo del manifiesto (fuera de `_DUPLICADOS_REVISAR`) → `_DUPLICADOS_REVISAR\<carpeta del original>\<nombre original>__COPIA_n<ext>`. Misma huella ZIP → `__COPIA_CONTENIDO_n`. Ambos se añaden al manifiesto, fila a fila desde v1.9.2 (`VersionSkill=1.9.2-vigilante`; antes `1.2-vigilante`). Las carpetas sueltas no se deduplican aquí: pasan a `INPUT` y la tarea de Claude las compara (ver punto 2).
   - Lo demás se mueve a `INPUT` (estado `EN_COLA`).
   - Aplica cada `planes_pendientes\plan_*.csv` con `Aplicar_Plan.ps1 -Ejecutar` y lo traslada a `planes_aplicados`.
   - Registra todo en `vigilante_<AAAAMM>.csv`.
2. **Tarea programada de Claude por bloques** (desde v1.9.1; en la sesión de referencia: `Organizar DESCARGAS por bloques (cada hora)`, `CRON_TZ=Europe/Madrid 37 8-22 * * *`, ligada al equipo, aprobación automática; sustituye a la tarea diaria de 08:48, que no daba abasto con ~1.100 archivos). Cada ejecución clasifica como máximo 60 elementos (archivos o carpetas) de `INPUT`, empezando por los más antiguos, excluye los listados en `_ORGANIZACION\nuevos_en_espera.txt` (decisión pendiente del usuario; líneas `#` son comentarios) y no genera bloque si hay un plan pendiente. Las carpetas se clasifican como unidad (`Tipo=carpeta`); si ya existe una clasificada con el mismo nombre y los mismos archivos (nombres relativos y tamaños), se mueven a `_DUPLICADOS_REVISAR\<ruta del original>` como `<nombre>__COPIA_n`. Lectura con `device_stage_files` en lotes de 3–6 archivos y ≤ 60 MB (lotes mayores agotan el tiempo de respuesta). Nota: el listado del equipo puede ir varios minutos por detrás del disco en Google Drive; `device_stage_files` lee el contenido actual. Su prompt debe:
   - Cargar este skill.
   - Si `INPUT` está vacío, omitir la clasificación (sin informe, salvo incidencias o resultados de módulos activos); si ya hay un plan en `planes_pendientes` sin aplicar, no generar otro.
   - Seguir las fases 1–6 con los archivos de `INPUT` (lectura de contenido, duplicados contra manifiesto y `huellas_zip.csv`, clasificación, nombres, validación y prueba con `pwsh` en réplica).
   - **No pedir doble clic**: escribir el plan con `device_commit_files` en `_ORGANIZACION\planes_pendientes\plan_<AAAAMMDD_HHMM>.csv`, desde un archivo de salida con nombre único, y comprobar su tamaño. El vigilante lo aplicará en ≤ 10–15 min.
   - Nunca borrar, nunca hacer clic, no citar datos sensibles; terminar con un resumen breve.
   - **Leer primero `_ORGANIZACION\config_plataforma.csv`** (v1.11) para conocer la raíz y la carpeta de entrada; los planes citan la entrada actual (`INPUT\...`).
   - **Control de salud (v1.11):** comprobar en `vigilante_latido_<AAAAMM>.csv` que hay un `FIN_OK` en los últimos 30 min y que no existe `vigilante_sin_raiz.txt` reciente; si no, empezar el resumen con «VIGILANTE DETENIDO» y la causa probable (equipo apagado, sesión cerrada, Drive sin montar, tarea de Windows deshabilitada).
   - **M14 (v1.11):** tras clasificar, indexar un lote (ver M14).
   - **Módulos activos (v1.6):** leer `_ORGANIZACION\config_modulos.csv` y, **aunque `INPUT` esté vacío**, ejecutar los módulos con `Activo=SI` que correspondan a la tarea diaria (M17 entrada de correo, si está activado, antes de clasificar; M18 y M19 en modo informe después). Revisar también `ALERTA_INTEGRIDAD.txt` (M16) y `copia_*.csv` (M15) y, si hay incidencias, incluirlas al principio del resumen.
3. **Reversión:** cualquier pasada se deshace con `Deshacer.ps1 -Registro <registro_*.csv>`. Los movimientos del vigilante a `INPUT` o `_DUPLICADOS_REVISAR` constan en `vigilante_<AAAAMM>.csv` (columnas Origen/Destino) y se revierten igual.
4. **Desinstalar:** `DESINSTALAR_VIGILANTE.bat`.

Limitaciones a comunicar: el borrado desde el panel no se deshace con `Deshacer.ps1`: se recupera desde la papelera de Google Drive (30 días); el equipo debe estar encendido, con la sesión iniciada y la app de escritorio de Claude abierta a la hora de la tarea diaria; la sincronización de Google Drive puede retrasar la aparición de archivos; si un archivo llega mientras se aplica un plan, se procesa en la pasada siguiente.

## Módulos avanzados (v1.6)

- **M1–M9:** las nueve propuestas de organización documental formuladas en la sesión de referencia, en el mismo orden (relación valor/esfuerzo).
- **M10–M14:** módulos complementarios incorporados en la v1.3 y restituidos en la v1.5 a petición del usuario. La auditoría de privacidad y credenciales de la v1.3 está íntegramente contenida en el M6.
- **M15–M19:** módulos de protección e inteligencia del archivo añadidos en la v1.6 a petición del usuario.
- **M20 (v1.10):** panel de duplicados con borrado verificado, a petición del usuario (05‑10‑2026). Siempre activo; lo genera y lo atiende el vigilante.
- **Activación:** M1–M7 y M9–M14 se ejecutan **bajo demanda** (cuando el usuario los pide, por nombre o por su objetivo). La M8 ya está implantada (sección «Modo automático»). M15–M19 se rigen por `_ORGANIZACION\config_modulos.csv`.

### Interruptores de activación (`config_modulos.csv`)
- Formato: `Modulo;Nombre;Activo;Modo;Parametros` (`;`, UTF‑8 con BOM). `Activo` admite `SI`, `NO` o `BAJO_DEMANDA`; `Parametros` va como `clave=valor` separados por `|`, con listas separadas por comas.
- **Valores por defecto:** M15 Copia verificable = `NO`; M16 Integridad = `SI`; M17 Entrada desde correo = `NO`; M18 Preservación = `SI`; M19 Mapa de relaciones = `SI`.
- El usuario activa o desactiva un módulo editando la columna `Activo` o pidiéndolo en el chat; en ese caso Claude reescribe el archivo (nombre de salida único, comprobación de tamaño) y confirma el cambio.
- Si el archivo no existe, se crea con los valores por defecto. Un módulo con `Activo=SI` cuyo script local aún no esté instalado se informa como «activo, pendiente de implantar» y no se da por operativo.
- **Ningún módulo se elimina en futuras versiones del skill.**

### Reglas comunes
- **Fuente de verdad:** el manifiesto (`manifiesto_documental.csv`), `huellas_zip.csv` y los inventarios. Si el manifiesto no está al día, pedir antes `INVENTARIAR.bat`.
- **Salidas** en `_ORGANIZACION\modulos\<modulo>\<AAAAMMDD>\`: CSV (`;`, UTF‑8 con BOM), HTML autocontenido, JSON o XLSX. Cada salida lleva fecha, versión del skill y nº de archivos analizados.
- **Ningún módulo mueve, renombra ni borra por sí mismo.** Si un módulo concluye que algo debe moverse, genera filas de plan y las entrega por el circuito normal (fase 6 o `planes_pendientes`), con validación y prueba en réplica, y solo tras la aprobación del usuario en el chat.
- **Coste acotado:** como máximo 50 archivos / 500 MB por `device_stage_files`; lectura por lotes, priorizando lo nuevo o modificado, con índice incremental por SHA‑256 para no releer.
- **Privacidad:** DNI/NIE, IBAN y números de cuenta, tarjetas, datos de salud, credenciales y datos de terceros no se copian a ningún índice, informe, nombre de archivo ni al chat; se registra solo el tipo de hallazgo y su ubicación. Los artefactos que se publiquen son privados y sin datos personales.
- **Fundamentación:** toda norma o plazo legal se verifica en fuente oficial (BOE, EUR‑Lex, AEAT, AEPD, AESA) en el momento de usarlo y se cita con enlace. Ninguno de estos módulos constituye asesoramiento jurídico ni fiscal.
- **Informe al usuario:** breve, con cifras, limitaciones y avisos; sin recapitular pasos.

### M1. Control de caducidades con avisos
- **Objetivo:** no dejar caducar certificados, pólizas, autorizaciones, formación ni plazos. Caso real: los certificados de piloto AESA del archivo de referencia caducan en febrero de 2027.
- **Procedimiento:**
  1. Extraer de forma heurística, del texto de los documentos del manifiesto (certificados AESA, seguros, formación PRL, documentación CAE, contratos, notificaciones DEHU), las fechas asociadas a expresiones como «válido hasta», «fecha de caducidad», «vencimiento», «vigencia», «fecha de efecto / fin», «plazo de…».
  2. **Primera confirmación obligatoria:** cada vencimiento nuevo se presenta al usuario (documento, fecha, frase de origen y página) y solo pasa a `vencimientos.csv` con `Estado=CONFIRMADO` cuando el usuario lo valida. Los no confirmados quedan `PENDIENTE` y no generan avisos. Nunca se supone una fecha que no conste.
  3. **Avisos a 60 y 30 días:** con las herramientas de programación de la sesión, crear una tarea programada de un solo disparo por aviso (o una diaria que revise `vencimientos.csv`), solo tras confirmación expresa. Alternativa sin tareas: `vencimientos.ics` con alarmas `-P60D` y `-P30D` para importar en el calendario.
- **Salida:** `vencimientos.csv` (SHA256;RutaRelativa;TipoDocumento;FechaVencimiento;FraseOrigen;Pagina;Estado;Aviso60;Aviso30) y, en su caso, `vencimientos.ics`.
- **Limitación:** la extracción es heurística; de ahí la confirmación inicial.

### M2. Detector de versión vigente
- **Objetivo:** identificar, dentro de cada familia de versiones, la vigente o firmada y archivar las superadas. Casos reales: `Llerena_Memoria_Tecnica_*` (nueve variantes); la familia Tactical ocupa unos 390 MB.
- **Procedimiento:**
  1. Agrupar por nombre normalizado (sin `_vN`, `final`, `definitivo`, `firmado`, `signed`, `corregido`, `(n)`, fechas) y confirmar la pertenencia a la familia por similitud del texto extraído (`difflib`, umbral orientativo 0,80).
  2. Elegir la vigente por este orden: firmada (firma o marcador `firmado/signed`) → marcada final/definitiva → fecha de documento más reciente → fecha de modificación más reciente. Si hay empate o duda, se pregunta.
  3. Proponer mover las superadas a `<carpeta de la familia>\_HISTORICO\` mediante plan normal, **familia a familia** y solo tras aprobación.
- **Salida:** `familias_versiones.csv` (Familia;RutaRelativa;Orden;Marcador;Similitud;Vigente;MB).
- **Matiz técnico:** mover a `_HISTORICO` ordena, pero **no libera espacio** en Drive ni en disco, porque el skill no borra. El espacio solo se recupera si el usuario decide eliminar las versiones superadas; el informe lo cuantifica (MB por familia) para que esa decisión sea informada. Para liberar disco local sin borrar, puede usarse el modo «solo online» de Google Drive para escritorio sobre `_HISTORICO`, a criterio del usuario.

### M3. Paquetes documentales en un clic
- **Objetivo:** reunir en un único entregable la documentación que pide un cliente o una licitación. Ejemplos: expediente CAE/PRL de un cliente (EPI, formación, seguros, certificados AESA, certificado de la TGSS) o la documentación administrativa de una licitación.
- **Procedimiento:**
  1. Mantener la tabla `_ORGANIZACION\paquetes\tipos_paquete.csv` (TipoPaquete;Requisito;PatronBusqueda;Area;Obligatorio;Caduca). Si no existe o falta el tipo pedido, construirla con el usuario.
  2. Para cada requisito, tomar del manifiesto la versión vigente (M2) y no caducada (M1). Faltantes o caducados se avisan antes de generar; no se genera hasta que el usuario lo confirme.
  3. Generar `_PAQUETES\<Tipo>_<Cliente>_<AAAA-MM-DD>.zip` (copias, no movimientos) con `00_INDICE.pdf` o `.html` y `inventario_hashes.csv` (Requisito;Archivo;SHA256;Tamaño;Vigencia).
- **Notas:** `_PAQUETES` se excluye del análisis de duplicados y del vigilante (empieza por `_`); se entrega un único ZIP para no multiplicar copias sueltas.
- **Limitación:** exige mantener la tabla de requisitos por tipo de paquete.

### M4. Cadena de custodia para periciales
- **Objetivo:** poder demostrar que un informe pericial o entregable no ha cambiado desde su entrega.
- **Procedimiento:**
  1. Al indicar el usuario que un entregable se ha entregado, añadir una fila a `_ORGANIZACION\custodia\registro_custodia.csv`: RutaRelativa;SHA256;Tamaño;FechaHoraUTC;Expediente;Destinatario;HashFilaAnterior. El último campo encadena las filas (cadena de hashes), de modo que una alteración del propio registro sea detectable.
  2. **Informe de verificación** (`verificacion_<archivo>_<fecha>.html`): recalcula el SHA‑256 del archivo, lo compara con el registrado y comprueba la integridad de la cadena.
- **Limitación:** tiene valor técnico, **no fehaciente**. Para fehaciencia hace falta un sello cualificado de tiempo emitido por un prestador cualificado incluido en la lista de confianza (Reglamento (UE) 910/2014, eIDAS, art. 41), firma electrónica cualificada o depósito notarial. El skill puede preparar la solicitud de sello (hash RFC 3161, p. ej. `openssl ts -query`), pero el sellado lo contrata y realiza el usuario.

### M5. Libro de gastos automático
- **Objetivo:** obtener el libro de gastos y conciliarlo con el banco sin teclear.
- **Procedimiento:**
  1. De `02_STAEREA_ADMIN\Facturas_Recibos` extraer: proveedor, NIF/CIF del proveedor, nº de factura, fecha, base imponible, tipo y cuota de IVA, retención si consta y total. Comprobar que base + IVA − retención = total; si no cuadra, `REVISAR`.
  2. Generar la hoja de cálculo (artefacto Sheets o `.xlsx` si el usuario pide ese formato), con fórmulas de totales por trimestre y tipo de IVA.
  3. Cruzar con los extractos de `02_STAEREA_ADMIN\Bancos_Movimientos` (CSV, Norma 43 o PDF) por importe, fecha (±5 días) y concepto: `CONCILIADA` / `PENDIENTE` / `SIN_FACTURA`.
- **Privacidad:** no se copian números de cuenta ni IBAN; como mucho, los cuatro últimos dígitos.
- **Limitación:** la extracción de importes es heurística y requiere revisión; el resultado es una herramienta de control, no sustituye los libros registro oficiales ni el criterio del asesor fiscal.

### M6. Cumplimiento RGPD
- **Objetivo:** localizar datos personales de terceros, en especial categorías especiales (RGPD art. 9, como los informes de salud de un expediente), y proponer su tratamiento adecuado. Es el módulo más delicado.
- **Procedimiento:**
  1. Detección sin copiar valores: DNI/NIE (dígito de control), IBAN, tarjetas (Luhn), términos de salud y de credenciales (`password`, `contraseña`, `recovery`, `api_key`, `token`, `.env`, `.pem`, `.kdbx`), en texto extraído y nombres.
  2. **Matriz de tratamiento** inspirada en el registro de actividades (RGPD art. 30): ubicación, categoría de datos, interesados, finalidad, base jurídica (**la decide el usuario**), plazo de conservación por tipo (p. ej., Código de Comercio art. 30 y Ley General Tributaria arts. 29 y 66, verificados en el momento) y medidas.
  3. **Propuestas de medidas:** traslado a `09_PERSONAL_SENSIBLE` o al expediente correspondiente (por plan normal), cifrado (contenedor 7‑Zip AES‑256 o BitLocker) y revisión de permisos de compartición en Drive (con el conector de Google Drive, si está conectado, solo lectura de permisos). Credenciales: trasladar a un gestor de contraseñas.
- **Salida:** `rgpd_hallazgos.csv` (RutaRelativa;TipoHallazgo;Ubicacion;Recomendacion, sin valores) y `matriz_tratamiento.xlsx`.
- **Limitación:** debe validarse con criterio jurídico; el skill no determina bases jurídicas ni plazos por sí mismo.

### M7. Búsqueda en lenguaje natural sobre el archivo
- **Objetivo:** responder preguntas como «¿qué presupuesto enviamos a Mar Menor y cuál es el vigente?» con el documento citado.
- **Procedimiento:**
  1. Mantener `_ORGANIZACION\modulos\busqueda\indice_texto.jsonl` (SHA256;RutaRelativa;Area;Proyecto;Fecha;Vigente;Pagina;Texto), con texto de `pdftotext`, `word/document.xml` y, para escaneos, OCR (`tesseract -l spa`, instalando si falta). Actualización incremental por SHA‑256.
  2. Al consultar: filtrar por metadatos (proyecto, área, fecha), puntuar por términos (BM25 o similar) y leer los mejores candidatos para responder **citando ruta y página**, priorizando la versión vigente (M2).
- **Exclusión:** `09_PERSONAL_SENSIBLE` y expedientes de terceros no se indexan salvo petición expresa.
- **Limitación:** los escaneos sin texto necesitan OCR previo (ya se detectaron varios); la calidad del OCR condiciona la respuesta.

### M8. Bandeja vigilada (implantada en v1.2)
- Está resuelta por el vigilante local y la tarea diaria (sección «Modo automático»).
- La propuesta original preveía que el usuario **aprobara** el plan; en la sesión de referencia el usuario eligió **autonomía total**, por lo que el plan se aplica sin aprobación. Para volver al modo con aprobación: la tarea diaria escribe el plan en `_ORGANIZACION\planes_propuestos\` y avisa; el usuario lo aprueba en el chat y entonces se traslada a `planes_pendientes`.
- **Limitación:** requiere el equipo encendido, la sesión iniciada y la app de escritorio abierta.

### M9. Panel del archivo
- **Objetivo:** ver de un vistazo el estado del archivo.
- **Indicadores:** volumen y nº de archivos por área; duplicados pendientes en `_DUPLICADOS_REVISAR` y MB; próximos vencimientos confirmados (M1) a 30/60/90 días; documentos sin clasificar (`INPUT` y `99_REVISAR_SIN_CLASIFICAR`); versiones superadas (M2) y MB; actividad del vigilante (pasadas, errores, planes aplicados).
- **Salida:** artefacto privado (panel HTML) alimentado por el manifiesto, sin rutas ni nombres de documentos sensibles; puede regenerarse en cada ejecución diaria si la tarea lo incluye.

### M10. Expedientes virtuales e índice transversal
- **Objetivo:** ver todo lo relativo a un proyecto, cliente, organismo o equipo aunque esté repartido en varias áreas, sin duplicar ni mover archivos.
- **Procedimiento:** agrupar las filas del manifiesto por prefijo de contexto del nombre (`Llerena_`, `AESA_`, `Expediente_…`) y por las entidades del M14; generar `expedientes.csv` (Expediente;RutaRelativa;Tipo;Fecha;SHA256;Vigente) y un `expediente_<nombre>.html` con enlaces relativos a cada documento, ordenado cronológicamente y marcando la versión vigente (M2).
- **Salida opcional:** carpeta `_EXPEDIENTES_VIRTUALES\<nombre>\` con accesos directos `.lnk` generados por un script PowerShell (WScript.Shell) que el usuario lanza con doble clic. Los accesos directos no son documentos: el vigilante los ignora por empezar por `_`, y se excluyen del inventario de duplicados.

### M11. Fichas resumen de documentos
- **Objetivo:** saber de qué trata un documento sin abrirlo (papers, contratos, pliegos, memorias técnicas, informes).
- **Procedimiento:** leer las primeras páginas y redactar una ficha de 3–5 líneas: qué es, quién lo emite, para qué proyecto, fecha, conclusiones u obligaciones clave. Para papers: referencia bibliográfica (autor, año, revista, DOI si consta) y aportación principal. Índice incremental por SHA‑256.
- **Indicador de completitud (v1.8, obligatorio en documentación):** cada ficha lleva `completitud` = {`estado`: COMPLETO | INCOMPLETO | EXTRACTO | NO_DETERMINABLE, `porcentaje` (0–100 o null), `paginas_pdf`, `paginas_esperadas` (o null), `evidencia`}. Ejemplo: libro de 400 páginas íntegro → COMPLETO, 100 %, 400/400.
  - Páginas esperadas, por orden de preferencia: rango de páginas de la cita (p. ej. 260–281 → 22) o «x of N» de la cabecera; «Página X de N»; última página del índice o sumario frente a la última página impresa; cierre del documento (referencias completas, contraportada, «Fin»).
  - Las portadillas de descarga (1–2 páginas añadidas por la editorial) no restan completitud. Un extracto de un número o de una obra mayor es EXTRACTO; si el total no consta, `porcentaje` = null. Sin evidencia suficiente: NO_DETERMINABLE, nunca un porcentaje supuesto.
  - En la página de fichas se muestra como distintivo (Completo · 100 % · 22/22 págs.) con filtro «No completos».
- **Salida:** `fichas.jsonl` y `fichas.html` navegable por área; las fichas alimentan también la búsqueda del M7. Primera ejecución: 04‑10‑2026, 71 fichas de `07_DOCUMENTACION` en `_ORGANIZACION\modulos\M11\20261004\` (69 completas, 2 extractos), publicadas además como artefacto privado «Fichero de Documentación».
- **Lección de la primera ejecución:** las fichas sirven también de control de calidad de la clasificación. Detectaron una guía jurídica en el campo 12, un archivo cuyo nombre decía «manual» y era la hoja de contenido del embalaje, ediciones mal indicadas en el nombre y editoriales nombrados como «Paper_». Las discrepancias se corrigen por plan normal (`plan_20261004_2000_correcciones_doc.csv`).
- **Traer documentos de Google Drive (modo streaming):** `device_stage_files` con lotes de 3–6 archivos o ≤ 60 MB; lotes de 50 archivos agotaron el tiempo de respuesta del equipo y coincidieron con una pasada del vigilante que no terminó.
- **Exclusión:** no se resumen documentos de `09_PERSONAL_SENSIBLE` ni expedientes de terceros.

### M12. Casi duplicados y duplicados semánticos
- **Objetivo:** detectar lo que el SHA‑256 y la huella ZIP no ven.
- **Casos:**
  - mismo documento en distinto formato (DOCX y su PDF exportado, PDF escaneado y PDF nativo): similitud del texto extraído ≥ 0,90;
  - imágenes iguales recomprimidas, redimensionadas o con otro formato: hash perceptual (`imagehash` pHash, distancia de Hamming ≤ 6);
  - ZIP y carpeta resultante de descomprimirlo: huella del ZIP contra la lista `ruta|tamaño|CRC32` de la carpeta;
  - PDF iguales salvo metadatos o firma: texto idéntico y mismo nº de páginas.
- **Salida:** `casi_duplicados.csv` (Grupo;RutaRelativa;Criterio;Similitud;Propuesta). Son **avisos**: solo pasan a plan, con `Accion=DUPLICADO` y sufijo `__COPIA_SIMILAR_n`, si el usuario lo confirma grupo a grupo. Se distinguen de las familias de versiones del M2 (contenido que evoluciona) porque aquí el contenido es el mismo.

### M13. Retención y ciclo de vida documental
- **Objetivo:** saber qué hay que conservar, hasta cuándo, y qué puede archivarse.
- **Procedimiento:** asignar a cada tipo documental una regla de conservación con su fundamento legal verificado en el momento (referencias de partida, a comprobar: Código de Comercio art. 30 —seis años para libros, correspondencia, documentación y justificantes del negocio—; Ley 58/2003 General Tributaria arts. 29 y 66‑70 —prescripción tributaria de cuatro años, ampliable cuando hay actuaciones que la interrumpen—; normativa laboral y de Seguridad Social; normativa AESA para operadores UAS). Calcular la fecha de fin de conservación desde la fecha del documento (M14). Comparte tabla de plazos con la matriz de tratamiento del M6.
- **Salida:** `retencion.csv` (RutaRelativa;TipoDocumental;Regla;Fundamento;FinConservacion;Estado: CONSERVAR|ARCHIVABLE|REVISAR). Lo `ARCHIVABLE` solo se propone mover a `_ARCHIVO_HISTORICO\<año>\` por plan normal. **Nunca se propone borrar**; la decisión de destrucción es del usuario y queda fuera del skill.

### M14. Índice de metadatos y entidades
- **Objetivo:** buscar y filtrar por organismo, empresa, proyecto, fecha, nº de expediente o importe sin abrir los documentos; es la base de datos estructurada que alimentan M1, M5, M7, M10 y M13.
- **Procedimiento:** sobre el texto extraído (incluido OCR de escaneos), detectar: fechas del documento, organismos emisores, razón social y CIF de **empresas**, nº de factura/expediente/registro, importes totales de documentos **propios**, municipio y referencias catastrales de proyectos. Índice incremental por SHA‑256.
- **Implantación (v1.11):** `src/m14/m14_extraer.py` y `src/m14/m14_siguiente_lote.py` del repositorio, desplegados en `_ORGANIZACION\modulos\M14\` y ejecutados en el contenedor de la tarea horaria (que los trae con `device_stage_files`):
  1. `m14_siguiente_lote.py --manifiesto … --estado _ORGANIZACION\modulos\M14\m14_estado.csv --salida lote.csv --max 60 --max-mb 300` elige los pendientes (última fila por ruta, sin borrados, `_*` ni entrada, solo formatos con texto, ≤ 50 MB cada uno) por prioridad de área 01, 02, 08, 03, 07, 05, 04, 10, 11, 06, 99, 09 e imprime la cobertura.
  2. Traer esos archivos con `device_stage_files` (lotes ≤ 50 archivos y ≤ 300 MB) y escribir `lote.csv` con `SHA256;RutaRelativa;RutaLocal`.
  3. `m14_extraer.py --lote lote.csv --indice indice_entidades.csv --estado m14_estado.csv` (añade `--ocr` para escaneos, más lento). **Solo reglas**, sin IA: fechas (numéricas, ISO y textuales), organismos (lista fija + «Ayuntamiento/Universidad/Ministerio/Consejería/Diputación de …»), CIF de persona jurídica con dígito de control, razón social con S.L./S.A./S.Coop., expediente, nº de factura, referencia catastral, proyecto por la ruta y tipo de documento. **Nunca** DNI/NIE, IBAN, tarjetas, teléfonos, correos, nombres de personas físicas ni importes.
  4. Resultado por archivo en `m14_estado.csv`: `OK`, `SIN_ENTIDADES` (Claude puede leer hasta 10 por hora y completar a mano con las mismas reglas de privacidad), `SIN_TEXTO` (escaneo: OCR en otra pasada) o `ERROR`.
  5. Devolver `indice_entidades.csv` y `m14_estado.csv` a `_ORGANIZACION\modulos\M14\` (anexando; nombre de salida único y comprobación de tamaño).
  - Ritmo previsto: ~60 documentos/hora; el archivo (~1.300 documentos con texto) se completa en 1–2 días. Coste: solo transferencia y CPU del contenedor; la lectura con IA queda limitada a los `SIN_ENTIDADES`. La elección del modelo para esa lectura (Haiku/Sonnet/Opus) está pendiente de un piloto comparativo con el usuario.
  - Validación: 15 pruebas (`tests/test_m14.py`), todas superadas, incluidas la ausencia de DNI e IBAN en el índice y la restricción de `09` a tipo y fecha.
- **Salida:** `indice_entidades.csv` (SHA256;RutaRelativa;Campo;Valor;Pagina;Confianza;Version) y `m14_estado.csv` (SHA256;RutaRelativa;Fecha;Resultado;Entidades;Version).
- **Exclusión:** `09_PERSONAL_SENSIBLE` y expedientes de terceros solo se indexan por tipo y fecha.

### M15. Copia de seguridad verificable (desactivado por defecto)
- **Motivo:** Google Drive para escritorio sincroniza; no es una copia de seguridad. Un borrado, una sobrescritura o un cifrado malicioso en el equipo se propagan a la nube.
- **Diseño:**
  - Destino configurable en `Parametros` (`Destino=`): disco externo u otra ubicación **no sincronizada** con la raíz. Sin destino válido el módulo no se ejecuta y lo informa.
  - Áreas configurables (`Areas=`; por defecto 01, 02, 08 y 09).
  - **Copia incremental sin espejo:** solo se añaden archivos nuevos o modificados; nunca se borra ni se sobrescribe nada en el destino (prohibido `robocopy /MIR` o `/PURGE`). Las versiones modificadas se guardan junto a la anterior con sufijo de fecha, de modo que un cifrado en origen no destruye la copia previa.
  - **Verificación:** SHA‑256 de cada archivo copiado comparado con el manifiesto; resultado en `_ORGANIZACION\copia_<AAAAMMDD>.csv` (Archivo;SHA256Origen;SHA256Destino;Estado).
- **Implantación (v1.11):** `_ORGANIZACION\Copia_Verificada.ps1`, instalado e **inactivo** hasta que el usuario indique el destino (`Activo=SI` y `Destino=` en la fila M15). El vigilante lo lanza en segundo plano una vez al día (`copia_ultima.txt`; latido `M15_COPIA_LANZADA`).
  - Destino `<Destino>\<nombre de la raíz>\…` con índice `_copia_indice.csv`; un archivo sin cambios (tamaño y fecha) no se vuelve a leer; cambio solo de fecha con el mismo hash no se copia.
  - Versión nueva → `<nombre>__v<AAAAMMDD_HHmmss>.<ext>` junto a la anterior; nunca se sobrescribe ni se borra en destino.
  - Rechaza destinos dentro de la raíz o en carpetas sincronizadas (`Mi unidad`, `My Drive`, Google Drive, OneDrive, Dropbox) → `DESTINO_RECHAZADO_SINCRONIZADO`. Destino ausente (disco desconectado) → `DESTINO_NO_DISPONIBLE`, se reintenta en la pasada siguiente.
  - No actúa mientras exista `vigilante.pausa` (alerta M16): no se copian archivos posiblemente cifrados.
  - Presupuesto por pasada `MaxGBPorPasada` (por defecto 50) y 120 min; si se agota o hay errores, continúa en la pasada siguiente.
  - Validación: 8 pruebas en réplica, todas superadas (copia inicial, sin cambios, versión «cifrada» junto a la buena, destino rechazado, destino no disponible, pausa M16, lanzamiento desde el vigilante).
- **Buena práctica a recordar:** regla 3‑2‑1 (tres copias, dos soportes, una fuera del lugar); un disco que se desconecta tras la copia protege también frente a ransomware.

### M16. Integridad y alerta temprana de ransomware (activo por defecto)
- **Comprobación de integridad:** cada día se recalcula el SHA‑256 de una muestra rotatoria del manifiesto (por defecto 1/7, de modo que todo el archivo se revisa semanalmente; `MuestraDiaria=`). Si el hash cambia sin que hayan cambiado tamaño ni fecha, se registra como **corrupción silenciosa**; si cambió con fecha nueva, como modificación legítima que actualiza el manifiesto.
- **Alerta temprana** en cada pasada del vigilante, por umbrales configurables:
  - más de `UmbralCambios10min` archivos (por defecto 200) modificados en 10 minutos fuera de la carpeta de entrada (v1.11: la configurada y sus nombres anteriores);
  - aparición de extensiones típicas de cifrado (`.locked`, `.encrypted`, `.crypt` y similares) o de notas de rescate (`README*`, `HOW_TO_DECRYPT*`, `*RESTORE*`) en varias carpetas;
  - archivos ofimáticos o PDF cuya cabecera ya no coincide con su extensión.
- **Respuesta:** crear `ALERTA_INTEGRIDAD.txt` en la raíz con el resumen, crear `_ORGANIZACION\vigilante.pausa` (el vigilante deja de mover y de aplicar planes mientras exista) y avisar en el siguiente informe de la tarea diaria. Solo el usuario retira la pausa.
- **Salida:** `integridad_<AAAAMM>.csv` (Fecha;RutaRelativa;SHA256Manifiesto;SHA256Actual;Diagnostico).
- **Implantación (v1.7, instalado el 04‑10‑2026):** `_ORGANIZACION\Verificar_Integridad.ps1` , invocado por el vigilante ; `REANUDAR_VIGILANTE.bat` retira la pausa tras confirmación y archiva la alerta y el archivo de pausa en `_ORGANIZACION\alertas\` (no los borra).
- **Detalles de implementación:**
  - El recuento de cambios masivos excluye `06_DESARROLLO_SOFTWARE` (las compilaciones no deben disparar alertas); las extensiones de cifrado sí se buscan en todas las áreas; las notas de rescate se buscan fuera de `06` y solo si se crearon en las últimas 24 h; extensiones exigen ≥ 5 archivos en ≥ 2 carpetas, notas ≥ 2 carpetas, cabeceras ≥ 3 archivos.
  - Firmas de cabecera comprobadas: PDF (`%PDF`), ZIP/Office Open XML/ODF (`PK`), JPEG, PNG, GIF y Office binario (OLE2).
  - La muestra diaria recorre el manifiesto con un **puntero rotatorio** guardado en `integridad_estado.csv` (cubre todo el archivo en `N` días según `MuestraDiaria=1/N`) y se limita a `MaxMBDiaria` (por defecto 4096 MB) para no forzar descargas masivas de Google Drive en modo *streaming*. Se toma la última fila de cada ruta del manifiesto (es de solo anexado).
  - Diagnósticos: `OK`; `MODIFICADO_LEGITIMO` (hash y fecha nuevos; se anexa fila `ACTUALIZADO_INTEGRIDAD` al manifiesto); `NO_ENCONTRADO` (movido por el usuario, no alerta); `CORRUPCION_SILENCIOSA` (hash distinto con mismo tamaño y fecha; alerta a partir de `MinCorrupcionesAlerta`, por defecto 5).
  - Parámetros en `config_modulos.csv` (fila M16): `MuestraDiaria`, `UmbralCambios10min`, `MaxMBDiaria`, `MinCorrupcionesAlerta`.
  - **v1.9:** en modo Alerta, `06_DESARROLLO_SOFTWARE` (más de 20.000 archivos) se recorre solo una vez cada 60 min (`-Intervalo06Min`, marca `integridad_ultimo_06.txt`) y al final del recorrido; el resto de áreas, en cada pasada. El recorrido se corta si supera `-PresupuestoSeg` (120 s por defecto, parámetro `PresupuestoM16Seg` del vigilante) y se registra `M16_ALERTA_PRESUPUESTO_AGOTADO` sin alertar. Contrapartida asumida: un cifrado limitado a `06` se detecta con hasta una hora de retraso.
  - **v1.9.1:** enumeración en *streaming* (`[IO.Directory]::EnumerateFiles`) para que el presupuesto corte de verdad; `Get-ChildItem -Recurse` recogía todo el árbol antes de iterar y una pasada quedó colgada más de 30 min.
  - **v1.9.2:** rotación de áreas: si el presupuesto se agota en un área, la pasada siguiente empieza por ella (marca `integridad_rotacion.txt`), para que ninguna carpeta quede sistemáticamente sin revisar; `06` va siempre al final. Corregido el registro, que anotaba la carpeta **siguiente** a la del corte.
  - **v1.10:** la muestra diaria ignora las rutas con fila `BORRADO_POR_USUARIO` en el manifiesto (no cuentan como `NO_ENCONTRADO`).
- **Validación v1.9.2–v1.10 (05‑10‑2026):** 66 pruebas en réplica con PowerShell 7, todas superadas: las 48 anteriores y 18 nuevas (tres copias iguales agrupadas con su original y verificadas; copia sin original no borrable; mismo tamaño con contenido distinto; presupuesto de borrado 0; solicitud no movida a `INPUT`; borrado de las tres copias conservando el original; rechazo de contenido distinto, de original ausente, de rutas fuera de `_DUPLICADOS_REVISAR` y con `..`; resultado y manifiesto; regeneración del panel con historial; muestra sin `NO_ENCONTRADO` tras borrar). El envío a la papelera de Drive solo es verificable en el equipo.
- **Validación v1.9 (04‑10‑2026):** se repitieron las 20 pruebas anteriores (todas superadas) y se añadieron 12: bloqueo v1.7 de 70 min recuperado, bloqueo reciente sin PID respetado, bloqueo con proceso vivo respetado, bloqueo con proceso muerto recuperado al momento, bloqueo de 40 min recuperado sin detener procesos no verificados, presupuesto agotado registrado sin alerta, `06` detectado en la primera pasada, omitido dentro del intervalo y vuelto a recorrer al vencer, latido `FIN_OK` con recuento y marca de `06` solo cuando se llega a recorrer (un `06` lento no se reintenta en cada pasada). La detención de un proceso colgado y las condiciones de batería solo son verificables en Windows.
- **Validación (04‑10‑2026):** 20 pruebas en réplica con PowerShell 7, todas superadas: base sin cambios, 250 cambios, cambios solo en `06`, extensiones de cifrado, notas de rescate, `README.txt` de software, cabeceras falsas, módulo desactivado, corrupción silenciosa por debajo y por encima del umbral, modificación legítima, archivo movido, no repetición en el mismo día, vigilante en pausa, vigilante normal y archivos que empiezan por `_`/`NN_`. El lanzamiento en segundo plano (`Start-Process -WindowStyle Hidden`) solo es verificable en Windows.
- **Limitación:** detecta, no impide; la protección efectiva frente a ransomware es la copia del M15 en un soporte desconectado. Fundamento metodológico: comprobaciones periódicas de fijeza del modelo OAIS (ISO 14721).

### M17. Entrada desde el correo (desactivado por defecto)
- **Objetivo:** que los adjuntos relevantes de Gmail lleguen a `INPUT` sin intervención manual; el remitente y el asunto mejoran la clasificación.
- **Procedimiento (tarea diaria, con el conector de Gmail):**
  1. Buscar mensajes que cumplan los criterios de `Parametros` (`Etiquetas=`, `Remitentes=`, `Desde=`); sin criterios definidos el módulo no se ejecuta.
  2. Descargar los adjuntos, si el conector lo permite, y escribirlos en `INPUT` con `device_commit_files`, anotando en `_ORGANIZACION\correo_procesados.csv` (IdMensaje;Fecha;Remitente;Asunto;Adjunto;SHA256) para no repetir.
  3. Pasar remitente y asunto como contexto a la clasificación del archivo.
- **Límites:** solo lectura del buzón: nunca envía, responde, archiva, etiqueta ni borra correos. Los adjuntos con datos de terceros se tratan según las reglas de privacidad. Si el conector no permite descargar adjuntos, el módulo lo informa y queda inoperativo.

### M18. Preservación a largo plazo (activo por defecto, en modo informe)
- **Objetivo:** que los documentos sigan siendo legibles dentro de muchos años.
- **Procedimiento:**
  1. Identificar formatos con riesgo de obsolescencia o dependencia de software (`.doc`, `.xls`, `.ppt` binarios antiguos, `.wps`, `.pages`, formatos propietarios de equipos) y PDF que no son PDF/A o no incrustan fuentes (`pdffonts`; validación PDF/A con veraPDF si está disponible).
  2. Proponer, para los documentos de conservación prolongada (M13), una **copia adicional** en PDF/A (ISO 19005), generada en el contenedor con LibreOffice o Ghostscript, con nombre `<nombre>__PDFA.pdf` junto al original. **El original nunca se sustituye ni se modifica.** Las copias se registran en el manifiesto con `Estado=COPIA_PRESERVACION`.
- **Activación por defecto:** genera el informe `preservacion.csv` (RutaRelativa;Formato;Riesgo;Propuesta). Las conversiones solo se hacen con aprobación del usuario, por lotes.
- **Limitación:** la conversión puede alterar la maquetación; cada lote se valida visualmente en muestra antes de escribirse.

### M19. Mapa de relaciones del archivo (activo por defecto, en modo informe)
- **Objetivo:** ver cómo se relacionan proyectos, clientes, organismos, equipos y documentos, y detectar huecos.
- **Procedimiento:** construir un grafo a partir del manifiesto, los prefijos de contexto y el índice de entidades (M14): nodos (Proyecto, Cliente, Organismo, Documento, Expediente) y aristas (pertenece a, emitido por, dirigido a, versión de, duplicado de).
- **Hallazgos:** documentos huérfanos (sin proyecto ni expediente), proyectos sin documentación clave (según una lista por tipo de proyecto, mantenida con el usuario), clientes con expedientes incompletos y entidades con muchos documentos sin clasificar.
- **Salida:** `grafo.json` y `grafo.graphml` (abrible en Gephi o yEd), `hallazgos_grafo.csv` y, si el usuario lo quiere, un artefacto privado con el grafo interactivo, sin nombres de documentos sensibles. Se regenera en la tarea diaria cuando cambian el manifiesto o el M14.
- **Limitación:** su calidad depende del índice de entidades (M14); mientras este no se haya construido, el grafo se limita a la estructura de carpetas y los prefijos de nombre.

### M20. Panel de duplicados y borrado verificado (activo, v1.10)
- **Objetivo:** revisar de un vistazo `_DUPLICADOS_REVISAR` y liberar espacio sin riesgo para los originales.
- **Panel:** `_DUPLICADOS_REVISAR\PANEL_DUPLICADOS.html`, autocontenido (datos embebidos; enlaces relativos que abren archivos y carpetas desde el navegador). Un registro por grupo: a la izquierda el documento clasificado que se conserva (miniatura, nombre, ruta, tamaño, SHA‑256 abreviado, otras ubicaciones con el mismo hash); a la derecha todas sus copias en `_DUPLICADOS_REVISAR` (miniatura, nombre, fecha en que se apartó y estado). Vista previa de imágenes, PDF y vídeo. Búsqueda, filtros por área, tipo y estado, orden por espacio, nº de copias, nombre o área, paginación de 40 grupos, modo claro y oscuro.
- **Agrupación:** el original se deduce del nombre (`<base>__COPIA[_CONTENIDO]_n<ext>` en `_DUPLICADOS_REVISAR\<carpeta del original>`), y si no existe, del SHA‑256 del manifiesto. Estados: `Idéntica` (mismo SHA‑256 en el manifiesto), `Mismo contenido` (ZIP), `Se verifica al borrar` (mismo tamaño; el vigilante compara el contenido completo) y `No se puede borrar` (original no localizado o tamaño distinto: la copia puede ser la única existente).
- **Marcado:** casilla por copia, botón «Marcar las copias de este grupo» (todas las copias de un grupo, p. ej. tres archivos iguales, conservando siempre el original) y «Marcar las copias visibles que se pueden borrar». «Borrar las copias marcadas» pide confirmación y descarga `SOLICITUD_BORRADO_DUPLICADOS_<AAAAMMDD_HHMMSS>.csv` (`RutaDuplicado;RutaOriginal;Tipo;Tamano;SHA256;Solicitado`). El vigilante la recoge sola de la carpeta Descargas del navegador, de la raíz o de la entrada (v1.11; carpetas configurables); el diálogo de confirmación del panel muestra las carpetas de recogida vigentes. El panel recuerda localmente las copias ya solicitadas.
- **Ejecución:** fase BORRADOS del vigilante (ver «Modo automático»). Nada se borra sin solicitud explícita del usuario y sin verificación en el momento.
- **Generación:** `Generar_Panel_Duplicados.ps1` , invocado por el vigilante; presupuesto 240 s (si se agota, el panel lo indica y se completa en la siguiente actualización). Para desactivarlo, renombrar el script.

## Avisos de seguridad y privacidad
- **Credenciales en texto plano:** recomendar trasladarlas a un gestor de contraseñas. No abrirlas ni citarlas.
- **Datos de salud o de terceros:** agruparlos en `09_PERSONAL_SENSIBLE` o en el expediente correspondiente. En la conversación se mencionan solo de forma genérica.
- No reproducir en el chat el contenido de los documentos personales; basta con el tipo de documento y la fecha.


## Configuración de la plataforma (v1.11)
- Archivo `_ORGANIZACION\config_plataforma.csv` (`Clave;Valor;Descripcion`, `;`, UTF‑8 con BOM), junto a los scripts:

| Clave | Por defecto | Uso |
|---|---|---|
| `RaizDocumental` | `G:\Mi unidad\DESCARGAS` | Carpeta que organiza el vigilante; debe contener `_ORGANIZACION` |
| `CarpetaEntrada` | `INPUT` | Bandeja de entrada dentro de la raíz; sin barras ni signos, no empieza por `_`, `.` ni `NN_` |
| `CarpetaSolicitudes` | `%DESCARGAS_NAVEGADOR%` | Carpetas de recogida de los CSV del panel, separadas por `|`; `%DESCARGAS_NAVEGADOR%` = Descargas de Windows (registro `User Shell Folders`, admite redirección). Siempre se añaden la raíz y la entrada |

- Se cambia con `CONFIGURAR_PLATAFORMA.bat` (menú) o `Configurar_Plataforma.ps1 -Clave <clave> -Valor <valor>` (`-Clave Restaurar` vuelve a los valores por defecto). Valida cada valor y no borra nada.
- **Cambio de raíz:** copia `_ORGANIZACION` y los `.bat` a la nueva raíz si no existen allí, escribe la configuración en ambas y vuelve a registrar el vigilante apuntando a la nueva; la raíz anterior queda intacta.
- **Cambio de entrada:** la siguiente pasada traslada la entrada anterior a la nueva (fase ENTRADA).
- El navegador decide dónde guarda las descargas; por eso el vigilante recoge de varias carpetas en lugar de pedir al usuario que mueva el archivo. Si el usuario usa otra carpeta de descargas, se añade con `|`.
- Claude, cuando el usuario pida cambiar una ruta en el chat, reescribe el archivo (nombre de salida único, comprobación de tamaño) o le indica el `.bat`; nunca ejecuta el `.bat` con uso del ordenador.

## Repositorio y despliegue (v1.11)
- **Repositorio:** `https://github.com/staerea/organizador-documental` (privado). Estructura: `src/` (fuente editable; `comun.ps1` se inserta en cada script en el marcador `#COMUN#`), `dist/` (scripts listos: UTF‑8 con BOM y CRLF), `tools/build.py`, `tests/` (`prueba*.ps1` con PowerShell 7 y `test_m14.py`), `config/` (valores por defecto), `docs/` (arquitectura, gobernanza, operación y decisiones ADR), `prompts/` (prompt de la tarea horaria), `skill/SKILL.md` (este archivo) y `CHANGELOG.md`.
- **Copia de respaldo del repositorio** en el equipo: `_ORGANIZACION\repositorio\organizador-documental.bundle` (`git clone organizador-documental.bundle` lo restaura sin GitHub). Se actualiza en cada versión.
- **Flujo de cambio:** 1) editar `src/`; 2) `python3 tools/build.py`; 3) ejecutar todas las pruebas (`tests/run_all.sh`) sin fallos; 4) commit con mensaje `vX.Y.Z: …` y etiqueta `vX.Y.Z`; 5) desplegar `dist/` en `_ORGANIZACION` (los `.bat` en la raíz) con `device_commit_files` desde nombres de salida únicos, comprobando tamaño o contenido; 6) actualizar `CHANGELOG.md`, el bundle y, si cambia el procedimiento, este skill.
- **Datos fuera del repositorio:** el manifiesto, los registros, inventarios, índices y resultados contienen rutas y nombres de documentos del usuario: nunca se suben (`.gitignore`).
- **Validación v1.11:** 115 pruebas, todas superadas: 77 de regresión (v1.2–v1.10.3, adaptadas a `INPUT`), 23 nuevas de v1.11 (migración `nuevos`→`INPUT`, colisiones, planes antiguos, recogida desde Descargas, solicitud repetida, panel con carpetas de recogida, raíz no disponible, validación y cambio de entrada, M16 sin alerta por la entrada, M15) y 15 del M14.

## Avisos de seguridad y privacidad (complemento v1.11)
- Recoger solicitudes de la carpeta de descargas amplía la superficie: un CSV ajeno con el nombre `SOLICITUD_BORRADO_DUPLICADOS_*` solo podría pedir borrar copias **dentro de `_DUPLICADOS_REVISAR` idénticas a un original que sigue en su carpeta**; la verificación del vigilante no cambia, de modo que el riesgo queda acotado a copias redundantes y recuperables 30 días en la papelera de Drive.
