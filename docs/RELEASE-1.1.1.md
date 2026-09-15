# AlienGamer Mode 1.1.1

Actualización correctiva del apagado coordinado desde la skin.

## Corrección principal

- El botón **OFF** usa ahora la misma función de cierre que **Detener monitor** en el icono de bandeja.
- Se cierran la skin, el puente de sensores y, cuando fueron iniciados por AlienGamer Mode, Rainmeter y HWiNFO.
- El estado del agente y el texto del menú de bandeja quedan sincronizados.
- Se añadió un canal local persistente para evitar que una diferencia de permisos entre Rainmeter y el agente pierda la orden de apagado.

## Instalación y actualización

1. Conserva instalados Rainmeter 4.5 o posterior y HWiNFO 7.34 o posterior.
2. Ejecuta `AlienGamerMode-Setup-1.1.1.exe` como administrador.
3. La actualización conserva la configuración compatible del usuario.

El instalador no incluye Rainmeter ni HWiNFO.

SHA-256 de `AlienGamerMode-Setup-1.1.1.exe`:

`1f718b7d4b42e66f03cc1e5c15f32aecb4c9d75a0a3a566deba161e540f9b005`

## Alcance de las pruebas

El cierre coordinado puede probarse con una sola pantalla. La selección, posición y escalado en un segundo monitor requieren una comprobación visual final cuando ese monitor esté conectado.
