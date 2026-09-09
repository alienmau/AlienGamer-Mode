# AlienGamer Mode

**Monitoreo adaptable de sensores y componentes del equipo para Windows.**

![Panel principal de AlienGamer Mode](docs/images/AlienGamerMode-dashboard.png)

AlienGamer Mode es un panel gamer creado con Rainmeter y HWiNFO. Detecta el hardware disponible, adapta el diseño a la pantalla seleccionada y muestra métricas útiles sin inventar valores cuando un sensor no existe.

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

## Instalación

1. Instala y configura los requisitos indicados arriba.
2. Descarga el instalador más reciente desde [Releases](https://github.com/alienmau/AlienGamer-Mode/releases/latest).
3. Ejecuta `AlienGamerMode-Setup-1.0.9.exe`.
4. Selecciona la pantalla, GPU y unidad de almacenamiento que deseas supervisar.
5. Finaliza la instalación; el panel se activa automáticamente y queda disponible desde el icono de la bandeja.

Consulta [Requisitos previos](docs/REQUISITOS-PREVIOS.md) y la [Guía de instalación manual](docs/GUIA-INSTALACION-MANUAL.md) si necesitas configurar HWiNFO o resolver un problema.

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

El monitor trabaja localmente. Los registros solo se crean cuando el usuario inicia una grabación y se guardan en la ubicación elegida. No publiques reportes que contengan información que consideres privada.

Los problemas de seguridad deben reportarse siguiendo [SECURITY.md](SECURITY.md), no como una incidencia pública.

## Contribuir

Las correcciones y propuestas son bienvenidas. Lee [CONTRIBUTING.md](CONTRIBUTING.md) antes de abrir una incidencia o enviar cambios.

## Licencia

El código propio se publica bajo la [licencia MIT](LICENSE). Los nombres, marcas y componentes de terceros conservan sus respectivas licencias. La fuente Dali no se incluye; la firma del autor se distribuye como una imagen rasterizada.

Creado por **Alienmau**.

