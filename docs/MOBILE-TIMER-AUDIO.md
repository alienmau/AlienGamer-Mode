# Alarma del temporizador / Timer alarm

Guía de la versión 1.9.0 / Version 1.9.0 guide.

## Español

Controla tu tiempo para jugar o trabajar: establece una sesión y recuerda levantarte, estirarte o alejarte un rato de la PC. Elige tu sonido de alarma entre cuatro efectos o selecciona tu propio MP3.

1. En el bloque Temporizador pulsa el icono **Configurar**. Ese mismo panel reúne **Tiempo** y **Sonido al finalizar**, sin otro desplegable. En **Reproducir alarma en**, elige **Sólo móvil**, **Sólo PC** o **Ambos**. Para cambiar tiempo o destino desde el móvil se requiere HTTPS confiable y autorización explícita de control en la PC; en sólo lectura permanecen disponibles los ajustes de sonido del propio móvil.
2. Elige Sonido 1–4; **Sonido 4** es el predeterminado. Para un archivo propio selecciona **Mi archivo MP3**, hasta 10 MB.
3. Pulsa **Activar y probar**. Confirma que escuchas el sonido y ajusta el volumen del dispositivo.
   Mientras suena, el botón cambia a **Detener**. Al detener o terminar vuelve a su estado de prueba. Guardar el tiempo o salir de la página detiene la reproducción.
4. Mantén la página abierta. Cuando la sesión pase de en curso a finalizada, el aviso se reproduce una sola vez.

Las preferencias y el MP3 propio se guardan en ese navegador, sin subir el archivo a la PC. Borrar datos del sitio, cambiar de navegador o cambiar de dirección del servidor puede requerir seleccionar el archivo de nuevo. Si el navegador no permite guardarlo, sólo estará disponible durante esa visita.

La elección de audio no modifica el tiempo compartido y también está disponible con el monitor de sólo lectura. Debes permitir el audio en cada nueva visita mediante **Activar y probar**. No se garantiza reproducción con pantalla bloqueada, página cerrada, pestaña suspendida, modo silencio o restricciones de batería. HTTPS confiable permite solicitar mantener la pantalla encendida cuando el navegador lo admite; no sustituye el permiso de audio.

### Sonido en PC, incluso con monitor sólo móvil

En el menú de AlienGamer Mode abre **Temporizador de sesión**. Elige dónde sonará la alarma y selecciona el sonido de PC: los mismos cuatro efectos (Sonido 4 predeterminado) o un MP3 propio de hasta 10 MB. **Probar en PC** permite escuchar la selección sin modificar las preferencias guardadas; **Cancelar** descarta los ajustes.

Al reproducir la prueba, ese mismo botón cambia a **Detener**. Puedes pararla sin esperar el final; al terminar vuelve a **Probar en PC**. **Guardar**, **Cancelar** y cerrar la ventana detienen automáticamente la prueba, sin detener una alarma real independiente.

Por defecto se sigue la salida de audio que Windows tenga seleccionada **cuando comienza la alarma**, sin fijar la salida existente al iniciar el monitor. En **Avanzado: elegir salida de audio de PC** puedes seleccionar un dispositivo concreto. Si no está disponible al comenzar, se usa la salida predeterminada de Windows y se muestra un aviso de bandeja. No se modifica volumen, silencio ni la salida predeterminada del sistema. La sesión de audio puede estar sujeta a las preferencias por aplicación del mezclador de Windows.

La alarma de PC depende del agente de AlienGamer Mode y funciona con cero pantallas físicas activas. Si cierras la aplicación o el equipo duerme/se apaga, no funciona como una alarma del sistema. Cambiar sólo el sonido o su destino no reinicia la cuenta. Si cambias la duración de una sesión en curso, se pide confirmación.

El tiempo y el destino PC/móvil/ambos son compartidos. El sonido propio del celular se conserva sólo en ese navegador; el sonido propio de PC se copia a los datos locales de la aplicación. Son selecciones independientes: no hay subida de archivos desde el celular ni descarga de archivos privados de la PC.

## English

Manage gaming or work sessions and use the timer as a reminder to stand up, stretch or take a break from your PC. Choose one of four alarm sounds or your own MP3.

Tap the timer's **Configurar** icon to open time and alarm settings in one panel. Choose a preset (Sound 4 is the default) or a custom MP3 up to 10 MB, then tap **Activar y probar** to enable and test audio. Keep the page open; completion plays once, without repeating on subsequent sensor updates. Read-only clients can configure local audio but cannot change shared time/output. Closing the panel stops preview.

Preferences and the custom file remain in that browser and are not uploaded to the PC. Clearing site data or changing browser/server address may require selecting the file again. Audio permission must be enabled each visit. Playback is not guaranteed when locked, closed, suspended, muted or restricted by battery policies. Trusted HTTPS enables supported screen wake lock, not automatic audio permission.

Choose Mobile only (default), PC only or Both from PC timer settings. Authorized mobile control over trusted HTTPS can change the shared output mode; read-only clients cannot change it. Local audio preferences and previews remain available in read-only mode.

PC settings offer the same four presets or a custom MP3. Windows' current default output is resolved when playback begins, or choose a specific device under Advanced. Missing devices fall back to Windows with a tray notice. Volume/mute/system defaults are not changed. The PC agent emits the alarm even with no desktop skin active, but cannot alarm when the app is closed or the PC is asleep/off. Audio-only changes preserve the countdown; changing an active duration requires confirmation.

PC and mobile custom sounds remain separate and private; neither PC file paths nor audio device IDs are exposed to web clients. The owner supplied the four effects from Pixabay under its Content License; they are third-party audio, not MIT-licensed code. See `src/mobile/sounds/README.txt` for provenance and license links.

Preview buttons switch to Stop while playing and reset after stop/completion. PC preview stops when saving/cancelling/closing; mobile playback stops on timer save or page exit. The PC dialog controls only its own preview worker, not a real completion alarm.
