# Arquitectura (v1.11)

## Visión general

```
                     ┌────────────────────────── Nube de Anthropic ──────────────────────────┐
                     │  Tarea horaria de Claude (08:37–22:37, Europe/Madrid)                 │
                     │   · lee config, latido y entrada  · clasifica ≤ 60 elementos          │
                     │   · escribe plan_*.csv             · M14 por lotes · informe/aviso    │
                     └───────────────▲───────────────────────────────┬───────────────────────┘
                                     │ device_stage_files            │ device_commit_files
                                     │ (lectura)                     │ (planes, índices)
┌────────────────────────────── Equipo Windows del usuario ──────────┼───────────────────────┐
│  Raíz documental (por defecto G:\Mi unidad\DESCARGAS, Google Drive) ▼                       │
│   INPUT\  ← entrada     NN_AREA\…  ← clasificado     _DUPLICADOS_REVISAR\ (+ panel)         │
│   _ORGANIZACION\  scripts · config_*.csv · manifiesto · registros · planes · módulos        │
│                                                                                             │
│  Tarea de Windows «Organizador_DESCARGAS_Vigilante» (cada 10 min, oculta, límite 30 min)    │
│   ENTRADA → M16 → MANIFIESTO → CONCILIAR → BORRADOS → RAIZ → PLANES → PANEL → FIN          │
│   (+ M15 diario en segundo plano)                                                           │
│                                                                                             │
│  Carpeta Descargas del navegador ── SOLICITUD_BORRADO_DUPLICADOS_*.csv ──► BORRADOS         │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

Las dos partes **no se llaman entre sí**: se comunican solo mediante archivos (planes CSV y registros). Si una falla, la otra sigue funcionando y todo el intercambio queda en disco (ADR‑0001).

## Fases del vigilante

| Fase | Presupuesto | Función |
|---|---|---|
| ENTRADA (v1.11) | — | Migra la carpeta de entrada si cambió de nombre (`nuevos` → `INPUT`) |
| M16_ALERTA | 120 s | Cambios masivos, extensiones de cifrado, notas de rescate, cabeceras; si hay alerta, pausa |
| (M16 muestra, M15 copia) | proceso aparte | Una vez al día cada uno |
| MANIFIESTO | — | Índices por SHA‑256 y huella ZIP |
| CONCILIAR | 180 s | Repone filas del manifiesto de pasadas cortadas |
| BORRADOS | 6 min | Recoge solicitudes (raíz, entrada, Descargas) y borra copias verificadas |
| RAIZ | hasta el min. 15 | Duplicados → `_DUPLICADOS_REVISAR`; resto → `INPUT` |
| PLANES | nuevos planes hasta el min. 12 | `Aplicar_Plan.ps1 -Ejecutar` (con resto si se agota) |
| PANEL | 300 s, proceso aparte | Regenera datos del panel (ranuras rotatorias) |
| FIN | — | Latido `FIN_OK` y `estado_plataforma.json` |

## Datos

| Archivo | Naturaleza | Escritura |
|---|---|---|
| `manifiesto_documental.csv` | Registro de clasificados (ruta, SHA‑256, tamaño, fecha, área, estado, versión) | Solo anexado, fila a fila |
| `vigilante_<AAAAMM>.csv` | Cada movimiento del vigilante (Origen/Destino/Estado) | Anexado |
| `vigilante_latido_<AAAAMM>.csv` | Una fila por evento de pasada | Anexado |
| `registro_<fecha>.csv` | Cada plan aplicado; base de `Deshacer.ps1` | Anexado |
| `config_plataforma.csv` | Raíz, entrada, carpetas de recogida | `Configurar_Plataforma.ps1` |
| `config_modulos.csv` | Interruptores M1–M19 | Usuario o Claude |
| `entrada_historial.txt` | Nombres que ha tenido la entrada | Vigilante |
| `borrados_solicitudes\` | Solicitudes y resultados (`procesadas\`, `repetidas\`) | Vigilante |
| `modulos\M14\indice_entidades.csv`, `m14_estado.csv` | Índice de entidades | Tarea horaria |
| `copia_<AAAAMMDD>.csv`, `<destino>\…\_copia_indice.csv` | M15 | `Copia_Verificada.ps1` |

## Decisiones

Ver `docs/adr/`.
