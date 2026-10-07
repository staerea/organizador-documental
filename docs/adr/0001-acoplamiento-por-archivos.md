# ADR-0001 — Acoplamiento por archivos entre la tarea de Claude y el vigilante
- **Estado:** aceptada (v1.2, 04-10-2026)
- **Contexto:** la shell remota en el equipo (`device_bash`) no está disponible de forma fiable y el uso del ordenador no debe ejecutar scripts.
- **Decisión:** Claude solo lee archivos (`device_stage_files`) y escribe planes CSV (`device_commit_files`). Un vigilante local, que es una tarea de Windows, los aplica.
- **Consecuencias:** las dos partes fallan de forma independiente y todo el intercambio queda auditado en disco. El precio es una latencia de hasta 10 minutos y la dependencia del PC encendido.
