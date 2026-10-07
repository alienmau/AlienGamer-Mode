# AlienGamer Mode 1.7.0 — Pantallas, móvil y nueva interfaz / Displays, mobile and refreshed UI

Cambios desde la última versión pública, **1.6.5**. Changes since the previous public release, **1.6.5**.

## Español

### Tu monitor también en un celular o tablet

Desde **Pantallas y distribución → Celular o tablet**, activa el monitor web y escanea el QR. La laptop y el dispositivo deben estar conectados al mismo router: Ethernet en la laptop y Wi-Fi en el teléfono funcionan juntos. No requiere una cuenta ni un servicio en la nube. Es una vista de sólo lectura de los sensores, no un control remoto del equipo.

- Vista responsiva en vertical y horizontal, con encabezado compacto, reloj matricial y gráficas circulares de RAM, VRAM, carga CPU/GPU, temperaturas agrupadas, FPS/tiempo de cuadro, alertas, temporizador y procesadores disponibles.
- **Editar** permite reordenar tarjetas mediante arrastre o flechas, elegir cuáles mostrar y cambiar su tamaño. **Mínimo** ocupa una unidad de columna; **Normal** conserva el ancho base de cada módulo; **Extendido** ocupa toda la fila. FPS y tiempo de cuadro son un mismo módulo; alertas es independiente.
- La distribución tipo masonry aprovecha los espacios bajo tarjetas de distinta altura. Al girar el dispositivo se conserva el tamaño elegido en unidades de columna y se redistribuyen los bloques. Si el contenido no cabe, se permite desplazamiento vertical en vez de recortarlo.
- Tarjetas translúcidas con estilo glassmorphism, valores centrados y colores de sensores coherentes con el escritorio. Fondo de luciérnagas decorativas cuyo color se elige desde el teléfono.
- Orden, visibilidad, tamaños y color decorativo se guardan por navegador/dispositivo. **Restablecer** recupera el diseño base. No altera la distribución de Rainmeter ni los colores de los sensores.
- **Expandir / Salir** entra o sale de pantalla completa cuando el navegador lo admite. Salir no apaga el monitor de Windows, HWiNFO ni Rainmeter.
- QR y enlace aparecen al activar el acceso; copiar muestra confirmación. **Nuevo QR** revoca el enlace anterior. Desactivar el acceso cierra el servicio móvil.

### Pantallas y distribución: nuevo diseño oscuro

- Interfaz en escala de grises con acento naranja, tipografía de Windows y controles redondeados, sin cambiar de framework.
- Tarjetas de pantallas físicas y acceso móvil en la sección superior; las pantallas adicionales se organizan en filas de hasta tres tarjetas. La selección y la activación de una pantalla siguen siendo acciones distintas.
- Vista previa centrada con proporción del monitor, módulos arrastrables/redimensionables, selección visible y protección contra solapamientos o posiciones fuera de pantalla. Los anillos del editor son esquemas, no lecturas en vivo.
- Panel inferior con navegación lateral vertical **Módulos / Fondo / Diseño**. El apartado activo lleva fondo gris elevado y texto fuerte; los márgenes separan botones, texto y opciones.
- Cada pantalla conserva su propio diseño, módulos y fondo. Las opciones globales de fondo/visibilidad se concentran en el editor para configurarlas por pantalla; el menú de bandeja conserva las acciones generales.
- Acciones **Descartar cambios / Guardar y aplicar** siempre al pie, estado de cambios y aviso de aplicación sobre las pantallas afectadas. Los cambios visuales reutilizan el perfil de sensores, sin reiniciar HWiNFO por cada ajuste.
- Tema homologado en el menú de bandeja y submenús, temporizador, hardware, QR, selector de color, progreso y avisos. Se conservan navegación de teclado y contraste alto de Windows.

### Correcciones y ajustes

- Asignación de pantallas por identidad física, no por el número DISPLAY1/DISPLAY2 que Windows puede cambiar. Si se desconecta el monitor asignado, su vista no se traslada silenciosamente al otro. Se vuelve a detectar la topología al aplicar.
- Corregido el error de instalación por `LiteralPath` nulo y el inicio de la tarea de HWiNFO rechazado con `0x800702E4`.
- Host gráfico para sensores y nuevo lanzador de procesos con `CreateNoWindow`, en lugar de depender de ocultar/minimizar consolas de PowerShell. Las pruebas verifican ausencia de consola, diálogos visibles y diagnóstico de errores; todavía se solicita confirmación del arranque instalado del usuario.
- Correcciones de codificación de formularios y de selección/validación de VRAM; los sensores ausentes o ambiguos no se presentan como ceros reales.
- El temporizador sin configurar muestra ceros y no permite iniciar. Tras definir una duración, al abrir otra sesión aparece esa duración lista para Play. **GAME OVER** queda fijo al terminar, sin zoom repetitivo; conserva la duración elegida, no una sesión terminada.
- Aviso al pasar de corriente a batería. No predice apagones ni evita pérdidas de Internet o problemas de un juego.

### Límites importantes e instalación

El servicio móvil usa **HTTP local**, una IP privada y el puerto **27844**. El enlace lleva un código secreto; la regla de firewall se limita al puerto y a la subred local. No configura reenvío de puertos ni ofrece acceso por Internet. Utilízalo únicamente en una red de confianza: HTTP no cifra el tráfico y no equivale a HTTPS.

**Mantener pantalla encendida no está disponible con el enlace HTTP actual.** Screen Wake Lock requiere un contexto seguro compatible; la opción explica por qué está deshabilitada. HTTPS local aún no está implementado. No se promete compatibilidad universal ni se modifican certificados o protecciones del teléfono. El aviso nativo de Chrome al entrar en pantalla completa tampoco puede modificarse desde la página.

Requiere Windows 10/11 de 64 bits, Rainmeter 4.5+ y HWiNFO 7.34+ con sensores/memoria compartida disponibles. Rainmeter y HWiNFO se instalan por separado. La instalación completa hace un refresco visual limpio, respalda los ajustes previos y conserva grabaciones/reportes. Una actualización puntual de la interfaz no equivale a reinstalar ni reinicia tus preferencias.

## English

### A live companion dashboard on your phone or tablet

Open **Displays and layout → Phone or tablet**, enable the web monitor and scan its QR. Both devices must use the same router; an Ethernet-connected laptop and a Wi-Fi phone can communicate on that LAN. No cloud account is required. This is a read-only sensor dashboard, not remote control of your PC.

- Responsive portrait/landscape views with a compact header, matrix clock, RAM/VRAM and CPU/GPU rings, grouped temperatures, FPS/frame time, separate alerts, session timer and available processor readings.
- **Edit** lets you drag or use arrows to reorder cards, hide/show them and select **Minimum**, **Normal** or **Extended** size. Minimum uses one column unit; Normal keeps the module's base width; Extended spans a complete row. FPS and frame time remain one module, separate from alerts.
- A natural-height masonry layout fills spaces beneath shorter cards. Column-unit sizes survive rotation while cards reflow; vertical scrolling is allowed when content cannot fit without clipping.
- Translucent glass-style cards, centered readings and sensor colors consistent with the desktop. Decorative fireflies have a selectable color.
- Layout and decorative preferences are stored per browser/device. Reset restores defaults without changing the Rainmeter layout or sensor colors.
- **Expand / Exit** requests or leaves fullscreen when supported. Exit only affects mobile fullscreen, not the Windows monitor or its services.
- Enabling access starts the local listener and displays the QR/link; copying gives feedback. Generating a new QR revokes the previous link; disabling access stops the mobile listener.

### Refreshed desktop configuration

The new dark **Displays and layout** interface uses neutral grays, an orange accent and rounded controls. Physical displays and mobile access appear as cards at the top; additional cards wrap into rows of up to three. Selection does not automatically enable a display.

The centered preview preserves screen proportions and supports moving/resizing modules with collision/boundary checks. Its rings are schematic, not live sensor readings. A vertical **Modules / Background / Layout** navigation rail sits beside the options below; the active section has a raised gray background and bold text, with generous spacing. Each display keeps independent visibility, placement, size and background settings. Global background/visibility options are organized in this per-display editor rather than scattered across the tray menu.

Persistent Discard/Save actions, unsaved-change feedback and an applying overlay clarify the workflow. Visual adjustments reuse the validated sensor profile rather than restarting HWiNFO each time. The same theme covers tray menus, timer/hardware/QR dialogs, color selection, progress and messages, retaining keyboard access and Windows High Contrast.

### Fixes and timer behavior

- Display assignment follows physical identity instead of changing DISPLAY numbers. Disconnecting a monitor does not silently move its layout to another; applying changes redetects the topology.
- Fixes setup's null `LiteralPath` failure and HWiNFO task launch failure `0x800702E4`.
- Adds GUI-subsystem sensor/process launchers and `CreateNoWindow` for background PowerShell children. Isolated tests verify no console allocation, visible graphical dialogs and preserved error/exit-code diagnostics; user confirmation of installed startup remains pending.
- Fixes dialog encoding and VRAM selection/validation. Missing/ambiguous sensors are not represented as real zeroes.
- An unconfigured session timer shows zeroes with Play disabled. A saved duration is restored ready to start when the monitor reopens. **GAME OVER** stays fixed at completion instead of repeatedly zooming; completed sessions are not resumed.
- Reports an AC-to-battery transition without claiming to predict outages or prevent game/network problems.

### Security, limitations and setup

The mobile service currently uses **plain HTTP**, a private LAN address and **TCP 27844**. A secret QR link is required and the firewall rule is scoped to the local subnet. It does not configure router forwarding or Internet access. Use a trusted network; HTTP is not encrypted.

**Keep screen awake is unavailable on the current HTTP LAN link.** Native Screen Wake Lock needs a supported secure context, and the UI explains the disabled option. Local HTTPS has not been implemented; no universal phone/browser guarantee, certificate changes or security bypasses are claimed. Browser-owned fullscreen notifications cannot be edited by this page.

Windows 10/11 x64, Rainmeter 4.5+ and HWiNFO 7.34+ are required separately. A full setup refreshes visual/timer settings with recoverable backups and preserves recordings/reports; a targeted UI update preserves preferences.

## Capturas / Screenshots

Mobile images are actual user-provided Chrome captures. Desktop images capture the implemented Windows Forms editor with test display data, not an HTML mockup. The five-monitor image is explicitly a simulated topology, not a claim of five connected physical displays.

![Editor de escritorio / Implemented desktop editor with test displays](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/display-editor.png)

![Vista móvil vertical / Real mobile portrait view](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-portrait.jpg)

![Vista móvil horizontal / Real mobile landscape view](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-landscape.jpg)

![Editor móvil / Real mobile layout editor](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.7.0/docs/images/release-1.7.0/mobile-editor.jpg)

[Cinco monitores simulados / Five simulated displays](https://github.com/alienmau/AlienGamer-Mode/blob/v1.7.0/docs/images/release-1.7.0/display-editor-five-simulated.png)

## Verificación / Verification

User approval covers the desktop direction and phone screenshots in portrait/landscape. Automated checks cover the shared desktop theme, simulated DPI containers (not physical DPI validation), two/five-display layouts, native GUI process launching, mobile server/QR controls and responsive editing. Mobile browser layout tests use synthetic readings. Physical tablet/iOS testing and final installed-console confirmation remain open; no new performance benchmark is claimed.

Planned, not included: trusted local HTTPS/wake-lock delivery and a minimal animated fan module driven by actual RPM when the hardware exposes that sensor. No release date or fan-speed control is promised.

Installer: `AlienGamerMode-Setup-1.7.0.exe`.

SHA-256: `ABB61462E927A2B91D6E31873BF9D31C2B3C417F2EB584800442E27E220B3FD1`.
