# AlienGamer Mode 1.3.4

## Actualización segura del grabador

- El instalador detiene procesos antiguos de grabación y búfer antes de sustituir archivos.
- Un CSV que estaba capturándose se conserva para recuperación; solo se limpian estados temporales.
- Las fechas del búfer previo se validan antes de incorporarlas al reporte.
- Las muestras con fecha vacía o inválida se omiten sin bloquear la sesión completa.

La corrección evita que un grabador iniciado con una versión anterior finalice durante la actualización usando código obsoleto.

SHA-256 de `AlienGamerMode-Setup-1.3.4.exe`:

`541913F17991C811A12E0742D1312E9129877BF48BAE863115E1937D70989753`
