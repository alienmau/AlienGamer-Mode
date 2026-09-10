# AlienGamer Mode

**Monitoreo adaptable de sensores y componentes del equipo para Windows.**

![AlienGamer Mode: monitoreo inteligente para gamers](docs/images/AlienGamerMode-social-preview.png)

[![Última versión](https://img.shields.io/github/v/release/alienmau/AlienGamer-Mode?style=for-the-badge&color=ff7a00)](https://github.com/alienmau/AlienGamer-Mode/releases/latest)
[![Descargas](https://img.shields.io/github/downloads/alienmau/AlienGamer-Mode/total?style=for-the-badge&color=22d3ee)](https://github.com/alienmau/AlienGamer-Mode/releases)
[![Licencia MIT](https://img.shields.io/github/license/alienmau/AlienGamer-Mode?style=for-the-badge&color=84cc16)](LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-2563eb?style=for-the-badge)](#requisitos)

**[Descargar la última versión](https://github.com/alienmau/AlienGamer-Mode/releases/latest)** · **[Guía de instalación](docs/GUIA-INSTALACION-MANUAL.md)** · **[Reportar un problema](https://github.com/alienmau/AlienGamer-Mode/issues/new/choose)**

AlienGamer Mode es un panel gamer creado con Rainmeter y HWiNFO. Detecta el hardware disponible, adapta el diseño a la pantalla seleccionada y muestra métricas útiles sin inventar valores cuando un sensor no existe.

## ¿Por qué AlienGamer Mode?

Un contador de FPS dice que algo ocurrió; AlienGamer Mode ayuda a conservar el contexto técnico del momento. Si notas un tirón, congelamiento, teletransporte o caída de fluidez, puedes iniciar una grabación y obtener un reporte que relacione el comportamiento del juego con temperaturas, carga, memoria, tiempo de cuadro y alertas disponibles.

- **Adaptable:** detecta el hardware real y reorganiza los módulos disponibles.
- **Honesto con los datos:** un sensor ausente se oculta o muestra `N/D`; nunca se inventa como cero.
- **Útil para investigar:** registra el intervalo exacto donde percibiste el problema.
- **Local y abierto:** no envía telemetría y su código puede auditarse.
- **Pensado para OLED:** realiza pequeños desplazamientos para reducir elementos estáticos prolongados.

![Panel principal de AlienGamer Mode en ejecución](docs/images/AlienGamerMode-dashboard.png)

## Funciones principales

- RAM, VRAM, carga de CPU y GPU.
- Temperaturas de CPU, núcleo máximo, GPU y almacenamiento principal.
- Carga dinámica por núcleo; los núcleos inexistentes se ocultan y los restantes se reorganizan.
- FPS y *frame time* con clasificación visual de fluidez.
- Indicadores de límite térmico y de potencia cuando HWiNFO los proporciona.
- Reloj digital tipo matriz.
- Animación suavizada de anillos y destello en rangos críticos.
- Protección para pantallas OLED mediante pequeños desplazamientos periódicos.
- Grabación manual de eventos y exportación de registros para diagnóstico.
- Agente de bandeja para activar, detener, grabar y cerrar el monitor.
- Selección de monitor, GPU y unidad principal durante la instalación.

## Requisitos

- Windows 10 u 11 de 64 bits.
- [Rainmeter 4.5 o posterior](https://www.rainmeter.net/).
- [HWiNFO 7.34 o posterior](https://www.hwinfo.com/download/), con sensores y memoria compartida habilitados.
- Microsoft Excel es opcional; solo se necesita para abrir directamente los reportes `.xlsx`.

Rainmeter y HWiNFO son productos externos y no se distribuyen dentro de este repositorio.

## Compatibilidad

El instalador permite elegir pantalla, GPU y almacenamiento principal. La skin se construye según la resolución, escala DPI y sensores detectados. El proyecto nació en un Lenovo Legion, pero no está limitado a esa marca.

La validación comunitaria en combinaciones NVIDIA, AMD e Intel continúa. Si lo pruebas en otro equipo, abre un **Reporte de compatibilidad** desde [Issues](https://github.com/alienmau/AlienGamer-Mode/issues/new/choose); incluso un resultado correcto ayuda a documentar hardware confirmado.

## Instalación

1. Instala y configura los requisitos indicados arriba.
2. Descarga el instalador más reciente desde [Releases](https://github.com/alienmau/AlienGamer-Mode/releases/latest).
3. Ejecuta `AlienGamerMode-Setup-1.0.9.exe`.
4. Selecciona la pantalla, GPU y unidad de almacenamiento que deseas supervisar.
5. Finaliza la instalación; el panel se activa automáticamente y queda disponible desde el icono de la bandeja.

Consulta [Requisitos previos](docs/REQUISITOS-PREVIOS.md) y la [Guía de instalación manual](docs/GUIA-INSTALACION-MANUAL.md) si necesitas configurar HWiNFO o resolver un problema.

## Grabar un evento de rendimiento

Si durante una partida notas tirones, congelamientos, teletransportes, caídas de fluidez o cualquier comportamiento extraño, pulsa **Grabar evento** en el panel o en el icono de la bandeja. El botón cambia a **Finalizar grabación** mientras la captura está activa.

AlienGamer Mode toma muestras durante ese intervalo y conserva, cuando el equipo dispone de ellas, métricas como FPS, *frame time*, uso y temperatura de CPU y GPU, VRAM, RAM, temperatura del almacenamiento, carga por núcleo y señales de límite térmico o de potencia. Al finalizar, solicita dónde guardar un reporte de Excel con:

- cronología de las muestras;
- resumen estadístico y valores máximos;
- alertas observadas durante el evento;
- procesos activos y contexto del equipo;
- una interpretación preliminar basada en la evidencia disponible.

El reporte permite relacionar el instante del problema con temperaturas elevadas, saturación de recursos, límites térmicos o de potencia y variaciones anormales del tiempo de cuadro. Puede aportar datos técnicos valiosos a un especialista y ayudar a detectar una condición antes de que se vuelva recurrente. Es una herramienta de orientación: no sustituye los registros internos del juego, diagnósticos SMART detallados, análisis de red ni trazas especializadas, y por sí sola no confirma una falla de hardware.

## Estructura del proyecto

- `assets/`: logotipo, icono y firma convertida a imagen.
- `config/`: parámetros predeterminados editables sin modificar código.
- `docs/`: arquitectura, requisitos y guía de mantenimiento.
- `installer/`: asistente gráfico y proyecto de Inno Setup 6.
- `src/`: descubrimiento de hardware, puente de sensores, agente, grabador y skin.
- `tests/`: validaciones automatizadas y escenarios con sensores ausentes.

La [documentación de arquitectura](docs/ARQUITECTURA.md) explica el flujo completo para desarrolladores y asistentes de IA que den mantenimiento al proyecto.

## Compilar el instalador

Instala Inno Setup 6 y ejecuta:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\installer\Build-Installer.ps1
```

El instalador se genera dentro de `build/installer/`.

## Pruebas

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-AlienGamerMode.ps1
```

Antes de publicar una versión se recomienda probarla en equipos NVIDIA, AMD e Intel; CPU híbrida y convencional; varias resoluciones y escalas DPI; y configuraciones con sensores opcionales ausentes.

## Privacidad y seguridad

El monitor trabaja localmente. Los registros solo se crean cuando el usuario inicia una grabación y se guardan en la ubicación elegida. El reporte puede incluir nombres de procesos y características del equipo; revísalo antes de compartirlo y no publiques información que consideres privada.

Los problemas de seguridad deben reportarse siguiendo [SECURITY.md](SECURITY.md), no como una incidencia pública.

## Contribuir

Las correcciones y propuestas son bienvenidas. Lee [CONTRIBUTING.md](CONTRIBUTING.md) antes de abrir una incidencia o enviar cambios.

Si deseas compartir el proyecto, encontrarás publicaciones listas para adaptar, enlaces de imágenes y una guía para evitar spam en [Difusión y lanzamiento](docs/DIFUSION.md).

## Licencia

El código propio se publica bajo la [licencia MIT](LICENSE). Los nombres, marcas y componentes de terceros conservan sus respectivas licencias. La fuente Dali no se incluye; la firma del autor se distribuye como una imagen rasterizada.

Creado por **Alienmau**.
