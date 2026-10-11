# Publicación 1.8.0 / Publication record — 2026-10-10

La versión se publicó primero en GitHub y después en los tres hilos existentes, desde las sesiones del usuario en el navegador integrado. No se crearon hilos duplicados.

## GitHub

- [Release e instalador 1.8.0](https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.8.0).
- Código/tag: `v1.8.0`, commit `e280958`.
- Instalador: `AlienGamerMode-Setup-1.8.0.exe`, 10,264,519 bytes.
- SHA-256: `ADD02CF36FC8E1B5D12607B23B9620B369C4C7A1AC193E50C5A7BA89DD8DAB2A`.
- Archivo SHA-256 publicado junto al instalador. La API pública confirma `v1.8.0` como última versión, no borrador.
- [Notas ES/EN](RELEASE-1.8.0.md), [guía HTTPS](MOBILE-HTTPS-GUIDE.md) y capturas disponibles en la versión.

## Foros — envío y contenido verificados

- **Rainmeter — English:** [respuesta 246061](https://forum.rainmeter.net/viewtopic.php?p=246061#p246061). Autor `alienmau`, versión 1.8.0, enlace de descarga/guía y dos imágenes insertadas: temporizador nuevo y editor de escritorio.
- **HWiNFO — English:** [respuesta 53423](https://www.hwinfo.com/forum/threads/aliengamer-mode-1-1-0-%E2%80%94-monitor-en-espa%C3%B1ol-with-validated-hwinfo-event-reports.11325/post-53423). Autor `alienmau`; mismas funciones, límites, guía y dos imágenes insertadas.
- **Reddit r/PC_Gamer — español:** [comentario pf6tz7o](https://www.reddit.com/r/PC_Gamer/comments/1we2ksb/comment/pf6tz7o/). Autor `FunMix1558`; descarga, guía y enlaces a las capturas públicas.

Se explica HTTPS opcional, CA/no Wi-Fi, no ignorar avisos rojos, conservación del certificado, pantalla encendida dependiente del navegador, control móvil del temporizador con autorización explícita, colores, iconos, fix de PowerShell, QR y «Conectando…». Se distinguen cambios nuevos de 1.8.0 del diseño ya presente en 1.7.0. No se afirma compatibilidad universal ni disponibilidad del módulo de ventiladores.

Comprobantes locales de navegador: `build/forum-proof-1.8.0/{rainmeter,hwinfo,reddit}.jpg` (no se publican sesiones/capturas de comprobación en el repositorio).

## Verificación del paquete

Compilación Inno Setup correcta. Pruebas en Windows PowerShell 5.1: validación oficial, dashboard móvil, procesos sin consola, migración de accesos, preferencias, asistente/diálogos anidados, temporizador compartido y migración, certificados/renovación y puente HTTPS real. Pruebas Node/Playwright: sintaxis, colores, arranque/control móvil y ocho tamaños/orientaciones. Las aserciones antiguas del temporizador por pantalla se actualizaron al contrato compartido, conservando verificaciones de sesión y controles deshabilitados sin configurar.

No se ejecutó la reinstalación completa sobre el equipo del usuario para probar este archivo: reinicia ajustes visuales/temporizadores y HWiNFO, y las funciones ya habían sido confirmadas en su instalación actual. Tampoco se probó este instalador en una máquina limpia ni en tablet/iOS físicos. Se publican pruebas de componentes y compilación, no una garantía para todos los equipos.

La primera publicación con el host PowerShell 5.1 quedó esperando antes de crear el release; se detuvo sólo ese publicador tras verificar ausencia de versión pública. Se añadió tiempo límite/progreso y se completó con PowerShell 7, verificando artefactos y estado público. No se modificó la confianza/certificado del usuario ni se reinició el monitor durante la publicación.
