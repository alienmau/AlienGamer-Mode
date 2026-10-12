# AlienGamer Mode 1.9.0 — Tu móvil como monitor de PC / Your mobile as a PC dashboard

2026-10-11 · Cambios desde 1.8.0 / Changes since 1.8.0.

## Español

### Más información a la vista, sin otro monitor

¿Sólo tienes un monitor? Juega en tu pantalla principal y consulta en tiempo real temperaturas, RAM/VRAM, uso de CPU/GPU y los datos de FPS disponibles desde tu smartphone o tablet en la misma red local. AlienGamer Mode permite usar **sólo el monitor móvil**, sin activar una vista de escritorio y sin exigir Rainmeter en ese modo. La PC por Ethernet y el móvil por Wi-Fi pueden compartir el mismo router.

La vista se adapta a vertical/horizontal, con tarjetas translúcidas, tamaños Mínimo/Normal/Extendido, reordenación, módulos visibles y luciérnagas decorativas configurables. Usa **Expandir** para pantalla completa; **Salir** sólo abandona ese modo en el dispositivo.

**Mantén la pantalla encendida** con el permiso nativo del navegador, HTTPS local confiable y el certificado generado en tu propia PC, cuando el dispositivo lo admita. La [guía HTTPS](https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-HTTPS-GUIDE.md) explica cómo comparar la huella, instalar como CA —no Wi-Fi— y comprobar «La conexión es segura». No se deben ignorar avisos rojos. Reiniciar, renovar el QR o actualizar conservando la misma autoridad no exige reinstalar la CA.

### Controla tu tiempo y elige tu sonido de alarma

Organiza sesiones de juego o trabajo y recuerda levantarte, estirarte o alejarte un rato de la PC. Un temporizador único mantiene la misma cuenta en todas las vistas.

- **Sólo móvil, Sólo PC o Ambos:** el destino de alarma se comparte. La PC puede sonar aunque todas las vistas físicas estén desactivadas; depende del agente, no de una skin abierta.
- **Cuatro sonidos integrados:** Sonido 4 (`timer-4.mp3`) es el predeterminado. También puedes seleccionar un MP3 propio de hasta 10 MB. El archivo del celular permanece en ese navegador; el de PC se conserva localmente, sin subir rutas ni archivos privados al monitor web.
- **Un solo botón Configurar** en móvil reúne tiempo, destino y sonido. En sólo lectura se permiten ajustes de sonido local, pero no cambios del tiempo/destino compartido. El control móvil necesita HTTPS y autorización explícita en la PC.
- **Probar ↔ Detener:** puedes parar la prueba sin esperar el final. Vuelve al estado de prueba al terminar; guardar o cerrar la configuración también la detiene. No afecta a una alarma real independiente de PC.
- **Salida de audio de PC:** por defecto sigue la que Windows tenga seleccionada al comenzar. En Avanzado puedes elegir un dispositivo concreto; si está desconectado, vuelve a Windows con aviso. No cambia volumen ni silencio.
- Cambiar sólo sonido/salida **no reinicia el contador**. Cambiar la duración de una sesión en curso pide confirmación. Se conserva verde/ámbar/rojo y GAME OVER fijo, sin zoom.

En móvil pulsa **Activar y probar** para permitir audio en esa visita y mantén la página abierta. El bloqueo, segundo plano, silencio, ahorro de batería y políticas del navegador pueden impedir el aviso. Tampoco sonará en PC con la aplicación cerrada o el equipo apagado/suspendido; no sustituye una alarma del sistema. Consulta la [guía de alarmas PC/móvil](https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-TIMER-AUDIO.md).

### Instalación, configuración y correcciones

- El instalador ofrece **Pantallas del equipo**, **Sólo celular/tablet** o **Ambos**; sólo móvil no exige elegir pantalla física y abre el acceso por QR al finalizar.
- El editor valida salida física **o** móvil, permite guardar sin pantallas físicas activas y mantiene el rechazo si todas las salidas están desactivadas. El perfil de sensores y HTTPS se conservan.
- **Configurar hardware** se limita a GPU/almacenamiento. Pantallas/móvil quedan en su editor. **Herramientas → Editar archivo de configuración** muestra aviso y respaldo antes de abrir Bloc de notas.
- Selector de color de luciérnagas con **barra arcoíris, vista previa y brillo**, sin introducir RGB; funciona con arrastre o teclado.
- Corregida la **ruta vacía al probar sonido en PC** capturando la raíz de la aplicación antes del callback del botón.
- Se mantiene la corrección de la consola PowerShell vacía y las mejoras de QR/HTTPS/temporizador compartido de la versión anterior; no se presentan como novedades de esta versión.
- README ES/EN centrados en el producto actual y capturas recientes; el detalle por versión permanece en Releases/CHANGELOG.

### Capturas y verificación

Las capturas nuevas del editor, instalador y temporizador utilizan las interfaces implementadas con datos de prueba, no una maqueta ni lecturas reales del equipo. No contienen QR privados, claves ni registros del usuario.

![Vista móvil vertical, datos de prueba](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.9.0/docs/images/release-1.9.0/mobile-portrait.png)

![Tiempo y sonido en un panel, datos de prueba](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.9.0/docs/images/release-1.9.0/mobile-timer-settings.png)

![Instalación sólo móvil, datos de prueba](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.9.0/docs/images/release-1.9.0/setup-mobile-only.png)

Pruebas de componentes en Windows PowerShell 5.1, reproducción real MP3 silenciada durante pruebas, salida predeterminada/específica/desconectada, pausa de prueba, modo sólo móvil, preferencias y conflictos, TLS real y límites del servicio, y ocho tamaños/orientaciones de navegador. No se afirma una nueva medición de recursos en juegos ni compatibilidad universal. No se ejecutó la reinstalación completa de este EXE sobre una máquina limpia; las funciones se aplicaron como parches locales para validación. Tablet/iOS físicos y ventiladores por RPM siguen pendientes. El reporte de un error al guardar fondo sigue pendiente de reproducción; no se afirma corregido sin evidencia.

**Instalación completa:** respalda/reinicia el diseño de escritorio y la sesión del temporizador; conserva grabaciones, reportes, preferencias móviles, ajustes de alarma y la autoridad HTTPS de la misma cuenta. HWiNFO es externo; Rainmeter sólo es requisito para escritorio. No requiere nube ni abrir puertos del router a Internet. Instala una CA únicamente tras verificarla y elimínala cuando ya no la uses.

## English

### More information in view, without a second monitor

Keep your game on your main display and check temperatures, RAM/VRAM, CPU/GPU use and available FPS readings in real time on a smartphone or tablet on the same LAN. **Mobile-only monitoring** now works with no active desktop dashboard and no Rainmeter requirement in that mode. Ethernet PC plus Wi-Fi phone can share a router.

The responsive dashboard retains portrait/landscape glass cards, ordering, visibility, Minimum/Normal/Extended sizes, decorative fireflies and fullscreen. Trusted local HTTPS, a certificate generated on your own PC and supported native wake lock can keep the screen awake; browser/device restrictions still apply. Follow the [HTTPS guide](https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-HTTPS-GUIDE.md), verify the fingerprint, install as a CA rather than Wi-Fi and require “Connection is secure.” Never bypass red warnings. The same CA survives restarts, QR rotation and same-authority updates.

### Manage your sessions and choose your alarm sound

Use one shared timer for gaming or work breaks: stand up, stretch or step away from the PC.

- Shared output: **Mobile only, PC only or Both**. The PC agent can alarm even without an active desktop skin.
- Four bundled sounds, **Sound 4 default**, or a custom MP3 up to 10 MB. Phone files stay in that browser; PC files remain local. No private PC file paths or device IDs are exposed to web clients.
- One mobile **Configure** icon groups time, output and sound. Read-only clients retain local audio preferences, but shared changes require trusted HTTPS and explicit PC permission.
- **Test/Stop** toggle, reset at completion and automatic preview stop on save/close; PC preview does not stop a separate real alarm.
- PC follows Windows' selected output at playback, or pins an advanced device. Missing devices fall back to Windows with a notice. Volume/mute are unchanged.
- Audio-only changes preserve the countdown; replacing an active duration requires confirmation. Green/amber/red transitions and fixed red GAME OVER remain.

Tap **Activar y probar** in the current Spanish mobile UI to allow audio for that visit, and keep the page open. Locked/backgrounded/suspended/muted devices may not sound. PC requires the agent running and an awake computer; this is not a system alarm. See the [alarm guide](https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-TIMER-AUDIO.md).

### Other changes and fixes

Setup destinations: Desktop displays, Phone/tablet only or Both; mobile-only needs no physical display selection and opens QR setup when finished. Layout validation accepts desktop or mobile output, rejects all-disabled configurations and preserves sensor profiles/HTTPS. Hardware configuration handles GPU/storage only; displays remain in their editor. Advanced configuration editing warns and backs up first. A rainbow/preview/brightness picker replaces RGB entry. Fixed the empty-path PC sound-preview callback. Retains the previous console-free startup, HTTPS/QR reliability and shared timer fixes.

Bilingual READMEs describe the current product; release history and detailed fixes remain in Releases/CHANGELOG. Screenshots show implemented interfaces with test data, not mockups or private user readings. Checks cover real muted MP3 playback, default/specific/disconnected outputs, preview cancellation, mobile-only startup, preferences/revisions, real TLS and eight browser sizes. No new gaming benchmark, clean-machine installer execution or universal support claim. Physical tablet/iOS validation and fan RPM remain open. A reported background-save error still awaits reproduction and is not claimed fixed.

Full setup backs up/resets desktop visuals and timer sessions, preserving recordings/reports, mobile and alarm preferences and same-account HTTPS authority. HWiNFO is external; Rainmeter is needed only for desktop views. No cloud or Internet forwarding. Trust the CA only after verification and remove it when no longer needed.
