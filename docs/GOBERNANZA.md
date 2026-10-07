# Gobernanza

## Principios (fijados por el usuario)

1. **No se borra ningún documento por iniciativa del sistema.** La única excepción es el borrado de copias redundantes que el usuario solicita desde el panel; el vigilante lo verifica antes de ejecutarlo (apartado «Circuito de borrado»).
2. **Todo es reversible y queda registrado** (manifiesto, registros, latido, resultados). Los borrados van a la papelera de Google Drive y se pueden recuperar durante 30 días.
3. **Nunca se ejecutan clics ni scripts mediante uso del ordenador.** Los `.bat` los ejecuta el usuario; lo automático lo ejecuta la tarea de Windows.
4. **Privacidad:** no se ponen datos de salud, DNI/NIE, IBAN, tarjetas, credenciales ni datos de terceros en nombres de archivo, índices, informes ni el chat. Las credenciales encontradas se recomiendan a un gestor de contraseñas.
5. **Ningún módulo se elimina** al actualizar el skill; solo se añaden o mejoran.
6. **Fuentes verificadas:** normas y plazos se comprueban en fuente oficial al usarlos; los módulos no constituyen asesoramiento jurídico ni fiscal.

## Separación de funciones

| Actor | Puede | No puede |
|---|---|---|
| Claude (tarea horaria o chat) | Leer, proponer planes, escribir planes en `planes_pendientes`, escribir índices e informes | Borrar, crear solicitudes de borrado, ejecutar scripts en el equipo |
| Vigilante | Mover, renombrar, aplicar planes, apartar duplicados, borrar copias **verificadas y solicitadas** | Borrar originales o cualquier cosa fuera de `_DUPLICADOS_REVISAR`; actuar en pausa M16 |
| Módulos | Generar informes y filas de plan | Mover, renombrar o borrar por sí mismos |
| Usuario | Aprobar, solicitar borrados, configurar rutas, retirar pausas | — |

## Circuito de borrado (doble control)

1. El usuario marca copias en `PANEL_DUPLICADOS.html` y confirma; el navegador descarga `SOLICITUD_BORRADO_DUPLICADOS_<fecha>.csv`.
2. El vigilante la recoge de la raíz, de la entrada o de las carpetas configuradas (por defecto, Descargas del navegador). Si ya la había recibido, la archiva como repetida.
3. Comprueba cada fila:
   - la copia está dentro de `_DUPLICADOS_REVISAR`, sin `..`, y no es el panel;
   - el original está fuera de `_DUPLICADOS_REVISAR` y de `_ORGANIZACION`;
   - existen los dos;
   - el contenido es idéntico, recalculado en ese momento (SHA‑256 o huella ZIP).
4. Solo entonces borra la copia (papelera de Drive). Deja `BORRADO_POR_USUARIO` en el manifiesto y una línea en `resultado_<solicitud>.csv`.

## Autonomía

La clasificación funciona en autonomía total por decisión del usuario. Se puede volver al modo con aprobación: la tarea horaria escribe en `planes_propuestos\` y el usuario aprueba en el chat.

## Control de cambios

- Todo cambio de código pasa por el repositorio: `src/` → `tools/build.py` → `tests/run_all.sh` sin fallos → commit y etiqueta → despliegue de `dist/` → CHANGELOG.
- Las decisiones de diseño relevantes se registran como ADR en `docs/adr/`.
- El skill (`skill/SKILL.md`) se actualiza en el mismo commit que el cambio de procedimiento. El usuario lo guarda en su cuenta desde la tarjeta de propuesta.
- Los datos del usuario (manifiesto, registros, índices) nunca entran en el repositorio.
