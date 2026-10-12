# Publicación 1.9.0 / Publication preparation

Estado: **publicado en GitHub y en los tres hilos**, con envío verificado en Edge el 2026-10-11 (hora de México). El autor confirmó la procedencia Pixabay de los cuatro MP3 bajo su Content License; registro en `src/mobile/sounds/README.txt`.

## Enlaces de publicación verificados

- GitHub: https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.9.0 — Latest, instalador y SHA-256; código de versión `85fa995`.
- Rainmeter (inglés): https://forum.rainmeter.net/viewtopic.php?p=246109#p246109 — respuesta nueva, capturas incorporadas.
- HWiNFO (inglés): https://www.hwinfo.com/forum/posts/53426/ — respuesta #8, capturas incorporadas.
- Reddit r/PC_Gamer (español): https://www.reddit.com/r/PC_Gamer/comments/1we2ksb/comment/pfdkv2c/ — comentario nuevo, enlaces a capturas.
- Confirmaciones visuales locales en `build/rainmeter-1.9.0-published.png`, `build/hwinfo-1.9.0-published.png` y `build/reddit-1.9.0-published.png`; no se publican estas capturas de sesión.

Se publicó primero GitHub y después una respuesta en cada hilo existente, sin crear hilos duplicados. Rainmeter/HWiNFO en inglés, Reddit r/PC_Gamer en español.

## Paquete local

- Archivo: `build/installer/AlienGamerMode-Setup-1.9.0.exe`.
- Versión de archivo/producto: `1.9.0.0`.
- Tamaño: 12,233,064 bytes.
- SHA-256: `941F914AA8211241D90502A6F677614349A1FEFC796E704A84B60CD7FF59126A`.
- Archivo SHA-256 preparado. Si cambian licencia/créditos u otros archivos incluidos antes de publicar, se recompilará y actualizará este registro y el checksum.
- El instalador incluye las opciones sólo móvil/ambos, módulos de audio, los cuatro MP3, selector arcoíris, panel móvil unificado y corrección Probar/Detener/ruta vacía.
- Sin ejecución de reinstalación completa sobre el equipo del usuario ni máquina limpia. Pruebas de componentes y compilación, no garantía universal.

## Pruebas completadas

Windows PowerShell 5.1: `Test-AlienGamerMode`, `Test-MobileOnly`, `Test-MobilePreferencePreservation`, `Test-SharedTimer`, `Test-TimerAlarm`, `Test-DesktopTheme`, `Test-ColorSpectrum`, `Test-OutputDestination`, `Test-TimerAlarmUI`, `Test-EnfoqueEditor`, `Test-MobileDashboard`, `Test-MobileDialog`, `Test-MobileHttpsWizard`, `Test-MobileTls`, `Test-MobileTlsLive`, `Test-HiddenProcesses`, `Test-ShortcutMigration`.

Node/Playwright: sintaxis móvil, `Test-MobileLayout` (ocho tamaños/orientaciones, masonry/preferencias/fullscreen/wake lock), colores del temporizador, arranque/control y audio móvil real/MP3 propio/Probar-Detener/panel unificado. TLS real verifica los cuatro MP3, allowlist, cambios protegidos de destino y ausencia de IDs de audio en la respuesta.

## Rainmeter / HWiNFO — English draft (BBCode)

```text
[b]AlienGamer Mode 1.9.0 — your phone or tablet as a live PC dashboard[/b]

I'm the project author. Only one monitor? Keep your game on your main screen and check your PC's available temperatures, RAM/VRAM, CPU/GPU usage and FPS/frame-time data from a phone or tablet on the same local network, without leaving the game or buying a second monitor.

Version 1.9.0 makes mobile-only operation a first-class setup option: no active desktop dashboard is required, and Rainmeter is optional in this mode. HWiNFO remains the external sensor source; validation and N/D handling remain unchanged. Ethernet PC plus Wi-Fi phone can share the same router.

[b]Choose your alarm sound and take a break[/b]
The shared timer can remind you to stand up, stretch or step away during gaming/work sessions. Choose Mobile only, PC only or Both. The PC agent can sound even with no desktop skins active. Four bundled presets (Sound 4 default) or your own MP3 are available. One mobile Configure icon now groups time and sound; Test changes to Stop, and saving/closing stops preview. PC audio follows Windows' current output when playback begins, with an advanced device choice and fallback if disconnected. Audio-only changes do not reset the countdown.

[b]Keep the mobile screen awake[/b]
Trusted local HTTPS and a certificate generated on your PC enable native wake lock where the browser supports it. Verify the fingerprint, install as a CA (not Wi-Fi) and require “Connection is secure.” Never bypass red warnings. Mobile audio needs a user tap to enable it and an open page; locked/backgrounded/muted devices may not sound. Shared timer/output changes require HTTPS and explicit PC permission. Read-only users retain local sound preferences.

Also included: hardware settings separated from display layout, warned/backed-up advanced file editing, a rainbow/brightness firefly picker instead of RGB fields, mobile-only validation fixes, and the empty-path PC sound-preview correction. Responsive glass/masonry cards, ordering, sizes, fullscreen and console-free startup remain.

[url=https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.9.0]Installer, SHA-256 and detailed English/Spanish release notes[/url]
[url=https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-HTTPS-GUIDE.md]HTTPS / certificate guide[/url]
[url=https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-TIMER-AUDIO.md]Timer / sound / output guide[/url]

[img]https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.9.0/docs/images/release-1.9.0/mobile-landscape.png[/img]
[img]https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.9.0/docs/images/release-1.9.0/mobile-timer-settings.png[/img]
Implemented interfaces with test readings; no private QR links.

Full setup backs up/resets desktop visuals and timer sessions while retaining recordings/reports, mobile/alarm preferences and same-account HTTPS identity. No cloud service or router forwarding. Physical tablet/iOS validation, fan RPM and a reported background-save error awaiting reproduction remain open. No new gaming-session resource benchmark or clean-machine installer test is claimed. Feedback on hardware/browser compatibility is welcome.
```

## Reddit r/PC_Gamer — borrador español

```text
AlienGamer Mode 1.9.0: tu celular o tablet como monitor de tu PC. Soy el autor.

¿Sólo tienes un monitor? Puedes jugar en tu pantalla principal y consultar temperaturas, RAM/VRAM, uso de CPU/GPU y los datos de FPS disponibles en el celular, en tiempo real y sin salir del juego. Ahora puedes instalar y usar sólo la vista móvil, sin activar pantallas físicas; Rainmeter es opcional en ese modo y HWiNFO sigue siendo la fuente de sensores.

También puedes controlar tu tiempo para jugar o trabajar: configura una sesión que te recuerde levantarte, estirarte o alejarte un rato de la PC. Elige tu sonido de alarma entre cuatro efectos (Sonido 4 predeterminado) o tu propio MP3, y decide si sonará en Sólo móvil, Sólo PC o Ambos. La PC puede sonar aunque sólo uses el monitor del celular. Sigue la salida seleccionada en Windows o una salida avanzada elegida por ti; si está desconectada, vuelve a Windows con aviso.

El mismo botón Configurar del temporizador reúne tiempo y sonido. Probar cambia a Detener y guardar/cerrar corta la prueba. Cambiar sólo sonido o salida no reinicia el contador.

Mantener pantalla encendida utiliza el permiso nativo del navegador con HTTPS confiable y un certificado generado en tu propia PC. Sigue la guía: compara la huella, instala como CA (no Wi-Fi) y verifica “La conexión es segura”; no ignores avisos rojos. La alarma móvil requiere pulsar Activar y probar y mantener la página abierta; el bloqueo, silencio o segundo plano pueden impedirla. Cambiar tiempo/destino compartido desde el móvil requiere permiso explícito en PC y HTTPS.

Se mantienen tarjetas translúcidas adaptables, reordenación, tamaños, fullscreen y luciérnagas. Añadí instalación sólo móvil/ambos, selector de color arcoíris y brillo sin RGB, separación de hardware/pantallas y fixes de validación y ruta vacía al probar audio. No usa nube ni requiere abrir puertos del router; Ethernet en PC + Wi-Fi en móvil funciona con el mismo router.

Descarga, notas ES/EN y SHA-256:
https://github.com/alienmau/AlienGamer-Mode/releases/tag/v1.9.0

Guía HTTPS:
https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-HTTPS-GUIDE.md

Guía de alarmas:
https://github.com/alienmau/AlienGamer-Mode/blob/v1.9.0/docs/MOBILE-TIMER-AUDIO.md

Vista móvil (datos de prueba):
https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.9.0/docs/images/release-1.9.0/mobile-landscape.png

Tiempo y sonido integrados (datos de prueba):
https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.9.0/docs/images/release-1.9.0/mobile-timer-settings.png

La instalación completa respalda/reinicia diseño y sesión del temporizador, conservando grabaciones/reportes, preferencias móviles/alarma e identidad HTTPS de la misma cuenta. No hay una nueva medición durante juegos ni prueba del instalador en máquina limpia; tablet/iOS físicos, ventiladores RPM y un reporte de error al guardar fondo siguen pendientes. Se agradecen pruebas de compatibilidad.
```
