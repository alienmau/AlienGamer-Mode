# AlienGamer Mode 1.5.0

Versión de prueba multidisplay para Windows 10 y 11.

## Novedades

- Editor visual **Pantallas y distribución...** desde el icono de bandeja.
- Varias vistas simultáneas, una por monitor local seleccionado.
- Posición y visibilidad independientes para todos los bloques.
- Presets horizontales, vertical, rendimiento y temperaturas.
- Fondo personalizado, térmico o desactivado por pantalla.
- Persistencia automática y migración desde configuraciones anteriores.

## Diseño técnico

Las vistas comparten HWiNFO, el puente de sensores, el búfer y la grabación. Añadir una pantalla no crea otra lectura de memoria compartida. Solamente se generan configuraciones visuales adicionales de Rainmeter bajo `AlienGamerMode\\Views`.

## Alcance

Esta versión administra monitores conectados localmente. El uso de teléfonos o tabletas como clientes remotos no está incluido todavía.

## Validación recomendada

1. Abrir **Pantallas y distribución...**.
2. Activar dos pantallas y aplicar un preset diferente en cada una.
3. Arrastrar al menos un bloque, guardar y reiniciar el monitor.
4. Confirmar que OFF cierra todas las vistas.
5. Iniciar una grabación desde una pantalla y comprobar que el estado cambia en ambas.
6. Probar un monitor vertical si está disponible.

Instalador: `AlienGamerMode-Setup-1.5.0.exe`

SHA-256:

```text
A7C4903F30949145736A7C6D0BD8BF2D996497DDA5F3447E0FE945762E6DEC61
```
