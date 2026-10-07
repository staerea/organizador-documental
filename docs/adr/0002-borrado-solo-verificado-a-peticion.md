# ADR-0002 — Borrado solo de copias verificadas y a petición del usuario
- **Estado:** aceptada (v1.10, 05-10-2026)
- **Contexto:** `_DUPLICADOS_REVISAR` crecía sin límite. El principio de no borrar debía mantenerse para los documentos.
- **Decisión:** el panel solo genera una solicitud CSV; nunca borra. El vigilante borra una copia únicamente si se cumplen todas estas condiciones:
  - la copia está dentro de `_DUPLICADOS_REVISAR`;
  - su original existe fuera de esa carpeta;
  - el contenido de ambos es idéntico, recalculado en ese momento.

  El borrado va a la papelera de Drive. Claude nunca crea solicitudes.
- **Consecuencias:** el riesgo se limita a copias redundantes y recuperables durante 30 días. Estos borrados no se deshacen con `Deshacer.ps1`.
