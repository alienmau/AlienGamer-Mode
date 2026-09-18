# AlienGamer Mode 1.3.1

## Fondo dinámico térmico

- Nuevo submenú **Fondo** con modos **Desactivado**, **Personalizado** y **Dinámico térmico**.
- Color ambiental basado en la presión térmica válida más exigente entre CPU, Core Max y GPU.
- Una alerta de *thermal throttling* fuerza el estado rojo crítico.
- Densidad de luciérnagas vinculada a fluidez y estabilidad reciente de *frame time*, combinada con actividad CPU/GPU.
- Velocidad vinculada a la mayor actividad válida de CPU/GPU.
- Transiciones suaves diferenciadas para incrementos y decrementos de densidad, velocidad y color.
- Sensores ausentes se ignoran; no se convierten en ceros ni en falsos estados saludables.
- Cantidad y velocidad configuradas actúan como límites máximos del modo térmico.
- Se conserva el modo personalizado, protección OLED, interfaz español/inglés y funcionamiento sin captura de audio.

La versión mantiene **Event Intelligence**, el búfer previo de 60 segundos, las marcas de incidente, datos brutos, puntuación de estabilidad, comparación de sesiones, privacidad y modo compacto FPS de 1.3.0.

## Requisitos

- Windows 10/11 de 64 bits.
- Rainmeter 4.5 o posterior.
- HWiNFO64 7.34 o posterior con sensores y memoria compartida habilitados.
- Microsoft Excel solamente para abrir directamente los reportes `.xlsx`.

## Integridad del instalador

SHA-256 de `AlienGamerMode-Setup-1.3.1.exe`:

`1CCC73C3FB9A1F921C03B4824566FE0E9F5E765BAE8816A7E3FF6165B50A08D5`
