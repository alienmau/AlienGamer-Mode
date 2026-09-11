# AlienGamer Mode 1.1.0

Esta versión amplía la personalización visual sin sacrificar la integridad de los datos ni la grabación técnica de eventos.

## Novedades

- Fondo ambiental ligero con luciérnagas de tamaño, profundidad, velocidad, deriva y brillo variables.
- Ajustes persistentes de cantidad, velocidad, tamaño y color desde el icono de bandeja.
- Submenú **Módulos visibles** para mostrar u ocultar procesadores, FPS/frame time/alertas y reloj.
- Vista compacta: los sensores ocultos continúan disponibles para **Grabar evento**.
- Contenedores con mayor transparencia y estilo de cristal ahumado.
- Anillos con movimiento interpolado y pulso crítico entre rojo base y rojo intenso.
- Aplicación visual más rápida con mensaje de progreso.
- Puente reforzado para sobrevivir a consultas canceladas durante refrescos de Rainmeter, evitando ceros o `N/D` transitorios.
- Distribución 70/30 de partículas: la mayoría cubre hasta el 75% de la pantalla y una parte alcanza el borde superior.
- Protección OLED y adaptación a resolución/DPI conservadas.

## Consumo orientativo y requisitos

Con 48 luciérnagas y animación a 10 FPS, el equipo de desarrollo promedió aproximadamente 457 MB de RAM y 5.4% de CPU para AlienGamer Mode, Rainmeter y HWiNFO en conjunto. El resultado varía según hardware, sensores y otras skins.

- Mínimo: Windows 10/11 x64, procesador de dos núcleos, 4 GB de RAM y 100 MB libres.
- Recomendado: 8 GB de RAM para el monitor o 16 GB si se jugará en el mismo equipo.

## Instalación y actualización

1. Instala Rainmeter 4.5 o posterior y HWiNFO 7.34 o posterior desde sus sitios oficiales.
2. Habilita sensores y **Shared Memory Support** en HWiNFO.
3. Ejecuta `AlienGamerMode-Setup-1.1.0.exe` como administrador.
4. Selecciona monitor, GPU y unidad principal.

El instalador no incluye Rainmeter ni HWiNFO. Al actualizar una instalación existente conserva los parámetros compatibles y agrega los nuevos valores predeterminados que falten.

SHA-256 de `AlienGamerMode-Setup-1.1.0.exe`:

`eda9f9a8e30c96da18e5e051808904cce6ef4348937d7ae591a46d00c8c47864`

## Privacidad

Todo funciona localmente. Solo se crea un reporte cuando el usuario inicia **Grabar evento**, y se guarda en la ubicación elegida. Antes de compartir un reporte conviene revisar nombres de procesos y datos descriptivos del equipo.
