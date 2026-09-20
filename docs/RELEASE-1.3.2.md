# AlienGamer Mode 1.3.2

## Pantalla correcta incluso con juegos abiertos

- La pantalla elegida se guarda por su identidad física PnP.
- Los cambios de numeración de Windows (`DISPLAY1`, `DISPLAY11`, etc.) ya no invalidan la selección.
- El agente reafirma periódicamente las coordenadas sin reconstruir ni redibujar la skin.

## Reconfiguración sin reinstalar

El menú de bandeja incorpora **Configurar equipo y pantalla...** para cambiar:

- monitor de destino;
- GPU supervisada;
- SSD/HDD principal.

La selección se vuelve a validar y, si el monitor está activo, se reinicia brevemente para aplicarla.

## Protección de fluidez

- **Personalizado** y **Dinámico térmico** son mutuamente excluyentes.
- Cantidad, velocidad, tamaño y color manuales solo se habilitan en **Personalizado**.
- El modo térmico emplea parámetros automáticos propios y conservadores.
- A partir de 88% de uso de GPU, o ante *frame time* degradado, reduce progresivamente partículas y velocidad.
- La protección utiliza transiciones suaves y nunca interpreta sensores ausentes como cero real.

## Validación

- Pruebas de sintaxis y configuración JSON.
- Generación de skins manual, térmica, compacta, bilingüe y con módulos ocultos.
- Prueba real de identidad: una selección antigua `DISPLAY11` resolvió correctamente la pantalla física Lenovo actual como `DISPLAY1` secundaria.

SHA-256 de `AlienGamerMode-Setup-1.3.2.exe`:

`BFC57C738062EAF1E6FE5C0EF2B7DF268FC2D75BF87C8181A3F2FCC79F5C5CBF`
