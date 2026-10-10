# organizador-documental

Plataforma de gestión documental automatizada para una carpeta raíz sincronizada con Google Drive (por defecto `G:\Mi unidad\DESCARGAS`). Ordena, deduplica por SHA‑256, clasifica por áreas y renombra por contenido lo que llega a la bandeja de entrada (`INPUT`). Todo es reversible y queda registrado. Solo se borran copias redundantes verificadas, y únicamente cuando el usuario lo solicita.

**Versión actual:** 1.11.2 (10‑10‑2026). Historial en [CHANGELOG.md](CHANGELOG.md).

## Componentes

| Componente | Dónde se ejecuta | Función |
|---|---|---|
| `Vigilante_Raiz.ps1` | Equipo Windows, tarea programada cada 60 min (configurable), sin ventana | Lleva lo nuevo de la raíz a `INPUT`, aparta duplicados, aplica planes, atiende solicitudes del panel, comprueba la integridad (M16), lanza la copia (M15) y regenera el panel |
| `Aplicar_Plan.ps1` | Lo invoca el vigilante | Aplica los planes CSV de clasificación (mover, renombrar, apartar duplicados) con presupuesto de tiempo |
| `Verificar_Integridad.ps1` | Lo invoca el vigilante | M16: alerta temprana de ransomware y muestra rotatoria de fijeza |
| `Generar_Panel_Duplicados.ps1` | Lo invoca el vigilante | Panel HTML de `_DUPLICADOS_REVISAR` con marcado para borrado verificado |
| `Copia_Verificada.ps1` | Lo lanza el vigilante una vez al día | M15: copia incremental sin espejo a un destino no sincronizado |
| `Configurar_Plataforma.ps1` / `CONFIGURAR_PLATAFORMA.bat` | Lo ejecuta el usuario | Raíz, carpeta de entrada y carpetas de recogida de solicitudes |
| `Inventariar_Raiz.ps1` | Lo ejecuta el usuario | Inventario con SHA‑256 y siembra del manifiesto |
| `src/m14/*.py` | Contenedor de la tarea horaria de Claude | M14: índice de entidades por reglas |
| Tarea horaria de Claude (`prompts/tarea_horaria.md`) | Nube de Anthropic, enlazada al equipo | Clasifica `INPUT` en bloques de hasta 60 elementos, indexa (M14), comprueba la salud del sistema e informa |
| `skill/SKILL.md` | Cuenta de Claude | Normas del procedimiento (taxonomía, nombres, privacidad, módulos M1–M20) |

## Estructura del repositorio

```
src/        fuente editable (comun.ps1 se inserta en el marcador #COMUN#)
dist/       scripts listos para desplegar (UTF-8 con BOM, CRLF) — generados, no editar
tools/      build.py
tests/      prueba*.ps1 (PowerShell 7, réplicas) y test_m14.py; run_all.sh
config/     valores por defecto de config_plataforma.csv y config_modulos.csv
docs/       arquitectura, gobernanza, operación y decisiones (ADR)
prompts/    prompt de la tarea horaria
skill/      SKILL.md del skill organizador-documental
```

## Construir y probar

```bash
python3 tools/build.py          # src/ -> dist/
bash tests/run_all.sh           # 139 pruebas; requiere pwsh 7 y python3 con reportlab
```

## Desplegar

Copiar `dist/*.ps1`, `dist/PANEL_DUPLICADOS.html` (en `_DUPLICADOS_REVISAR`) y `config/*.csv` (solo si no existen) a `<raíz>\_ORGANIZACION\`, y los `.bat` a la raíz. El vigilante instalado los usa en su siguiente pasada; no hace falta reinstalar la tarea salvo que cambie `Instalar_Vigilante.ps1`. Procedimiento completo en [docs/OPERACION.md](docs/OPERACION.md).

## Datos que nunca se suben

El manifiesto, los registros, inventarios, índices, resultados y paneles generados contienen rutas y nombres de documentos del usuario. Están excluidos en `.gitignore` y no deben añadirse al repositorio.
