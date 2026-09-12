# Difusión y lanzamiento

Este archivo contiene textos listos para copiar y adaptar. Antes de publicar, revisa las reglas de cada comunidad, declara que eres el creador y evita repetir el mismo mensaje en varios espacios el mismo día.

La estrategia de la versión 1.1.0 prioriza comunidades hispanohablantes de Latinoamérica porque la interfaz actual está en español. Rainmeter y HWiNFO pueden recibir una publicación técnica bilingüe como difusión secundaria, indicando claramente el idioma de la interfaz. La difusión internacional general se ampliará cuando la siguiente versión planificada incorpore inglés.

## Enlaces oficiales

- Proyecto: https://github.com/alienmau/AlienGamer-Mode
- Descarga: https://github.com/alienmau/AlienGamer-Mode/releases/latest
- Portada horizontal: https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/main/docs/images/AlienGamerMode-social-preview.png
- Vista compacta: https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/main/docs/images/AlienGamerMode-compact.png
- Imagen cuadrada: https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/main/docs/images/AlienGamerMode-social-square.png

## Mensaje breve en español

### Título

AlienGamer Mode: monitor adaptable que registra problemas de rendimiento durante una partida

### Publicación

Hola. Soy el creador de **AlienGamer Mode**, un proyecto gratuito y de código abierto para Windows basado en Rainmeter y HWiNFO.

Muestra RAM, VRAM, CPU, GPU, temperaturas, carga por núcleo, FPS y *frame time*. Además, cuando notas tirones, congelamientos, teletransportes o caídas de fluidez, puedes pulsar **Grabar evento**. Al finalizar genera un reporte con la cronología de sensores, máximos, alertas y una interpretación preliminar que puede aportar contexto técnico para investigar lo ocurrido.

El instalador detecta el hardware disponible, permite seleccionar monitor, GPU y almacenamiento, y oculta los sensores ausentes en lugar de inventarlos como cero. También incorpora desplazamiento periódico para reducir elementos estáticos en pantallas OLED.

La versión 1.1.0 añade un fondo ambiental de luciérnagas configurable y permite ocultar de forma persistente los procesadores, el panel de FPS/alertas y el reloj para crear una vista compacta sin dejar de registrar esos sensores. En la medición del equipo de desarrollo, el conjunto completo utilizó aproximadamente 457 MB de RAM y 5.4% de CPU con la animación al máximo; se recomiendan 8 GB de RAM, o 16 GB si se jugará en el mismo equipo.

Actualmente busco personas con equipos diferentes que quieran probarlo y reportar compatibilidad. Rainmeter y HWiNFO son requisitos externos y se instalan desde sus sitios oficiales.

Proyecto y descarga: https://github.com/alienmau/AlienGamer-Mode

Agradezco comentarios, capturas y reportes de errores. Si esta publicación no corresponde a la sección, con gusto la muevo o retiro.

## Lenovo Legion — español

### Título

Creé un monitor de sensores para jugar en una segunda pantalla: AlienGamer Mode

### Publicación

Hola, comunidad. Desarrollé **AlienGamer Mode** originalmente en un Lenovo Legion, aunque la versión pública detecta y adapta sus módulos al hardware de cada equipo.

El panel muestra RAM, VRAM, uso y temperatura de CPU/GPU, almacenamiento, carga por núcleo, FPS y *frame time*. Su función más útil es **Grabar evento**: si aparece un tirón, congelamiento o caída de fluidez, registra ese intervalo y genera un reporte técnico para revisar temperaturas, carga, límites térmicos o de potencia y otras señales disponibles.

Es gratuito, de código abierto y funciona localmente con Rainmeter y HWiNFO. Estoy buscando más usuarios de Legion con diferentes generaciones, CPU, GPU, resoluciones y configuraciones híbridas para ampliar la matriz de compatibilidad.

Repositorio y descarga: https://github.com/alienmau/AlienGamer-Mode

Soy el autor del proyecto y agradeceré cualquier prueba o sugerencia.

## Rainmeter / r/desktops — English

### Title

AlienGamer Mode — an adaptive Rainmeter hardware monitor with event recording

### Post

Hi! I built **AlienGamer Mode**, a free and open-source Windows monitoring panel powered by Rainmeter and HWiNFO.

It displays RAM, VRAM, CPU/GPU load and temperatures, per-core activity, FPS and frame time. Its distinctive feature is **Record Event**: when you notice a stutter, freeze, rubber-banding or an unexpected frame-time spike, you can capture that interval and generate a technical report containing the sensor timeline, peaks, available thermal/power-limit flags and a preliminary interpretation.

The installer detects available hardware, lets the user choose the target display, GPU and primary storage device, and hides unavailable sensors instead of presenting invented zeroes. It also includes subtle periodic movement intended to reduce long-lived static elements on OLED displays.

Version 1.1.0 adds a configurable firefly-style ambient background and persistent visibility controls for the processor panel, FPS/alerts panel and clock. Hidden modules remain available to event reports. On the development machine, the complete stack averaged about 457 MB RAM and 5.4% total CPU with the visual effect at its maximum setting; actual usage varies by hardware and configuration.

The project is public and I am looking for testers with different NVIDIA, AMD and Intel configurations, resolutions and DPI scales.

Repository and latest release: https://github.com/alienmau/AlienGamer-Mode

Disclosure: I am the project author. Rainmeter and HWiNFO are external requirements and are not bundled.

## HWiNFO Forum — English

### Title

AlienGamer Mode: adaptive Rainmeter dashboard and HWiNFO event-report workflow

### Post

Hello. I am sharing **AlienGamer Mode**, an open-source Windows dashboard that consumes HWiNFO Shared Memory through a local bridge and renders an adaptive Rainmeter skin.

The project validates sensor labels, source, units, ranges and FPS/frame-time coherence before publishing values. Missing or ambiguous sensors are reported as unavailable rather than converted to zero. The generated layout adapts to the detected logical processors, selected GPU/storage device, monitor resolution and DPI scale.

Version 1.1.0 also adds a configurable lightweight firefly background and persistent module visibility without interrupting the HWiNFO bridge.

It also includes a user-triggered event recorder. During a perceived gameplay problem, the user records a bounded interval and receives an Excel report with time-series samples, percentiles, maximum values, active processes and available thermal or power-limit flags. The report is intended as diagnostic context, not as a definitive hardware diagnosis.

Source, documentation and installer: https://github.com/alienmau/AlienGamer-Mode

I am the project author and would appreciate feedback about sensor mapping across different HWiNFO versions and hardware combinations.

## Comunidades gamer — publicación corta

### Título

¿Tu juego se trabó? Este monitor permite grabar los sensores justo cuando ocurre

### Publicación

Desarrollé **AlienGamer Mode**, un monitor gratuito y abierto para Windows. Además de FPS, *frame time*, temperaturas, CPU, GPU, RAM y VRAM, permite pulsar **Grabar evento** cuando notas un tirón o congelamiento. Después genera un reporte técnico con lo ocurrido durante ese intervalo.

Busco probadores con diferentes equipos para mejorar la compatibilidad:
https://github.com/alienmau/AlienGamer-Mode

Soy el autor del proyecto. Requiere Rainmeter y HWiNFO instalados desde sus páginas oficiales.

## Respuestas rápidas

### ¿Es gratis?

Sí. El código propio utiliza licencia MIT. Rainmeter y HWiNFO conservan sus propias licencias.

### ¿Envía información?

No. El monitor funciona localmente. Los reportes solo se crean cuando el usuario inicia una grabación y se guardan donde este elija.

### ¿Diagnostica automáticamente una falla?

No de manera definitiva. El reporte relaciona métricas y alertas disponibles para orientar una investigación; algunos problemas requieren registros del juego, red, controladores, SMART detallado o trazas especializadas.

### ¿Funciona únicamente en Lenovo Legion?

No. Nació y fue validado inicialmente en un Legion, pero el instalador y la skin están diseñados para adaptarse al hardware detectado.

### ¿Por qué utiliza un instalador EXE?

Porque debe descubrir hardware, preparar la configuración local, crear la skin adaptada y coordinar el agente de bandeja. El código del instalador está disponible públicamente en el repositorio y la versión publicada incluye su SHA-256.

## Lista antes de publicar

1. Confirma que la comunidad permite autopromoción o proyectos propios.
2. Elige una sola imagen adecuada al formato.
3. Declara que eres el autor.
4. Explica el beneficio antes que la lista de funciones.
5. Incluye un solo enlace principal.
6. Responde preguntas técnicas y registra problemas reales como incidencias.
7. No publiques el mismo texto simultáneamente en comunidades relacionadas.
