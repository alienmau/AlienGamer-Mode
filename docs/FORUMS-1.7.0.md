# Respuestas para los hilos existentes — 1.7.0

## Publicación verificada — 7 de octubre de 2026

Las tres respuestas se enviaron desde las sesiones del usuario en el navegador integrado, después de que la conexión con Edge fallara. Se verificaron el autor, el contenido y los enlaces permanentes; las dos imágenes de cada foro cargaron correctamente. No se crearon hilos nuevos ni se duplicaron respuestas.

- **Rainmeter — inglés:** https://forum.rainmeter.net/viewtopic.php?p=245938#p245938
- **HWiNFO — inglés:** https://www.hwinfo.com/forum/threads/aliengamer-mode-1-1-0-%E2%80%94-monitor-en-espa%C3%B1ol-with-validated-hwinfo-event-reports.11325/post-53397
- **Reddit r/PC_Gamer — español:** https://www.reddit.com/r/PC_Gamer/comments/1we2ksb/comment/pee0u9x/
- **GitHub — notas bilingües e instalador:** https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.7.0

Rainmeter y HWiNFO incluyen imágenes del editor de Windows y de la vista móvil horizontal. Reddit incluye enlaces a las cuatro capturas. Los anuncios conservan las limitaciones de HTTP/HTTPS, pantalla encendida y la confirmación pendiente del arranque instalado; se añadió una breve descripción de los lenguajes usados y del módulo de ventiladores planeado. Los textos siguientes son los borradores de referencia, adaptados al enviarlos.

## Rainmeter — English / BBCode

AlienGamer Mode 1.7.0 — QR mobile companion and redesigned display editor

I'm the author of AlienGamer Mode. This update builds on 1.6.5 and keeps Rainmeter as the desktop renderer while adding a read-only local web companion for phones/tablets.

The desktop editor now has a dark gray/orange theme, rounded display cards at the top, a centered draggable/resizable preview, and vertical Modules / Background / Layout navigation below. Each physical display retains independent visibility, geometry and background settings. Additional display cards wrap into rows; Discard/Save remain at the bottom. The same visual language covers tray menus and configuration dialogs.

On the mobile side, scan a QR from a device on the same router (Ethernet PC + Wi-Fi phone works). Portrait/landscape cards use responsive masonry, glass-style surfaces and sensor rings. Edit supports drag/arrow ordering, visibility and Minimum / Normal / Extended widths, plus a selectable decorative firefly color. FPS/frame time is one card, separate from alerts. Preferences are per browser/device; the web page does not control Rainmeter or shut down the PC.

This release also fixes monitor assignment after DISPLAY-number changes, installer failures, dialog encoding and VRAM validation. GUI launchers now use CreateNoWindow rather than relying only on hidden/minimized PowerShell windows; isolated tests pass, with final installed-startup confirmation still open. The timer restores a saved duration ready for Play and keeps GAME OVER fixed at completion.

Important: the current LAN link is HTTP, not HTTPS. Keep screen awake is therefore disabled with an explanation; local HTTPS is not implemented yet. Fullscreen depends on the browser. Rainmeter and HWiNFO are separate requirements. Full setup backs up/resets visual settings while preserving recordings/reports.

[url=https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.7.0]Download, full Spanish/English notes and screenshots[/url]

[img]https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/display-editor.png[/img]
Desktop capture from the implemented Windows Forms editor using test display data, not an HTML mockup.

[img]https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-landscape.jpg[/img]
Actual user-provided Chrome mobile capture. Feedback on other resolutions/DPI and tablets is welcome.

## HWiNFO — English / BBCode

AlienGamer Mode 1.7.0: live HWiNFO readings on a phone/tablet over the local network

I'm the project author. Since 1.6.5, AlienGamer Mode adds a QR-accessible read-only mobile dashboard alongside its Rainmeter desktop views. The laptop and phone must be on the same router; the laptop may use Ethernet while the phone uses Wi-Fi. The existing sensor bridge serves the web view, without a cloud account or a separate mobile PowerShell worker.

The phone page shows available RAM/VRAM, CPU/GPU use, grouped temperatures, FPS/frame time, thermal/power alerts, timer state and processor activity. It adapts to portrait/landscape. Users can reorder/hide cards and choose one-column, base-width or full-row sizes, saved per browser. Decorative firefly colors are independent from sensor colors.

Reliability improvements include physical-monitor identity rather than changing DISPLAY numbers, re-detection before applying a layout, null-LiteralPath setup correction, the HWiNFO elevated-task launch fix for 0x800702E4, and VRAM validation. Missing or ambiguous readings are not substituted with real zeroes. Native GUI/process hosts prevent console allocation while preserving graphical dialogs and error diagnostics; isolated tests pass, but final installed-startup confirmation remains pending.

The desktop editor/dialogs also receive a coordinated dark orange-accent theme. The timer now restores its configured duration ready to start and displays GAME OVER without repeated zooming.

Security/limits: opt-in HTTP listener on a private LAN address, port 27844, secret QR link and local-subnet firewall scope. It offers no remote PC control or router forwarding. Use a trusted LAN: traffic is not encrypted. HTTPS and reliable screen-awake delivery are not implemented; the HTTP wake-lock option correctly explains why it is unavailable. Tablet/iOS physical testing remains open.

[url=https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.7.0]Installer, bilingual release notes, source and screenshots[/url]

[img]https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-landscape.jpg[/img]
Actual Chrome phone capture supplied by the user.

[img]https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/display-editor.png[/img]
Implemented desktop editor with test display data. Rainmeter and HWiNFO are installed separately. Feedback on sensor mapping across different hardware is welcome.

## Reddit r/PC_Gamer — Español / Markdown

Actualización de mi proyecto AlienGamer Mode: versión 1.7.0, ahora con monitor en el celular/tablet por QR y nuevo editor de pantallas.

Soy el autor. Si quieres tener temperaturas, RAM/VRAM, CPU/GPU y FPS/tiempo de cuadro a la vista sin ocupar la pantalla del juego, ahora puedes activar el servicio local desde la laptop y escanear un QR. Ambos equipos deben estar en el mismo router; la laptop por Ethernet y el celular por Wi-Fi funcionan juntos. No usa una cuenta en la nube ni permite controlar tu PC desde el teléfono.

La página se adapta al girar el celular. Desde Editar puedes mover/ocultar tarjetas y elegir Mínimo, Normal o Extendido; aprovecha los espacios con una distribución tipo masonry y conserva tus preferencias por navegador. Incluye tarjetas translúcidas, gráficas circulares, temperaturas agrupadas y luciérnagas con color configurable.

En Windows renové Pantallas y distribución con tema oscuro, acento naranja, tarjetas de monitores arriba, previsualización central y opciones verticales Módulos/Fondo/Diseño abajo. Cada monitor mantiene su propio diseño. También hay correcciones de asignación de pantallas, instalación, VRAM y codificación; el temporizador recupera tu duración lista para Play y deja GAME OVER fijo al terminar. El nuevo lanzador evita crear consolas en las pruebas; falta confirmar el arranque instalado final.

Importante: el servicio móvil actual es HTTP local, sólo para una red de confianza. HTTPS sigue pendiente y, por eso, mantener pantalla encendida aparece deshabilitado con una explicación. Pantalla completa depende del navegador; salir sólo abandona ese modo en el celular. Requiere Rainmeter y HWiNFO por separado.

[Descarga y notas detalladas en español/inglés](https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.7.0)

[Captura móvil vertical](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-portrait.jpg) · [Horizontal](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-landscape.jpg) · [Editor móvil](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-editor.jpg) · [Nuevo editor de pantallas](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/display-editor.png)

Las capturas móviles son reales; la captura del editor de Windows utiliza datos de pantallas de prueba. Se agradecen pruebas en otros celulares/tablets. El módulo de ventiladores por RPM queda como siguiente mejora, condicionado a que el hardware exponga ese sensor.
