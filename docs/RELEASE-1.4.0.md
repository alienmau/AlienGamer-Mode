# AlienGamer Mode 1.4.0

Esta versión convierte cada grabación en un paquete de evidencia más fácil de revisar y compartir.

## Nuevas funciones

- Generación automática de un reporte visual HTML al finalizar una grabación.
- Resumen ejecutivo, estabilidad de 0 a 100, métricas principales y contexto técnico.
- Cuatro gráficas responsivas: FPS, *frame time*, temperaturas y utilización.
- Tabla de incidentes con hora, etiqueta, ventana analizada e interpretación preliminar.
- Funcionamiento local y sin conexión; el reporte no carga bibliotecas ni envía telemetría.

## Mejoras

- FPS y *frame time* se muestran con escalas independientes.
- Presentación adaptable para escritorio, móvil e impresión.
- Español e inglés, codificación UTF-8 y acentos revisados.
- Asistente de privacidad aplicado también al HTML.
- Enlaces relativos al libro de Excel y al CSV guardados junto al reporte.

## Correcciones acumuladas

- Fechas vacías o inválidas ya no impiden finalizar el reporte.
- Una sesión sin incidentes genera correctamente sus archivos.
- El arranque, OFF y las acciones de la skin no dejan consolas visibles de PowerShell.
- OFF usa un cierre de respaldo que detiene Rainmeter, HWiNFO, puente y búfer si el agente no responde.

## Validación

- Prueba automatizada de HTML, Excel, CSV, privacidad, incidentes y cuatro gráficas.
- Generación verificada con una captura sintética y con una sesión real de 1,130 muestras.
- Revisión visual del reporte real en navegador.
- Pruebas integrales del instalador, configuración, skin, idiomas y cierre silencioso.

## Integridad

SHA-256 de `AlienGamerMode-Setup-1.4.0.exe`:

`F0EC363AE4709AD599ACC1C5D57BFA12570210CBB083AB01D2C45624AAED9A80`
