# AlienGamer Mode 1.3.5

Esta versión corrige el ciclo de inicio y cierre de la aplicación.

## Correcciones

- El agente de bandeja sigue siendo permanente, pero ahora se ejecuta mediante Windows Script Host con ventana oculta.
- El primer arranque, los accesos directos y el inicio automático ya no dejan una consola de PowerShell abierta.
- Los botones **OFF** y **Grabar evento** de la skin usan el mismo lanzador silencioso y no acumulan consolas vacías.
- OFF espera como máximo tres segundos la confirmación del agente. Si no llega, ejecuta una limpieza local de respaldo.
- La limpieza detiene la skin, el búfer previo, el puente, la tarea elevada de sensores, HWiNFO y Rainmeter; después corrige el estado persistente.

## Validación

- Análisis de sintaxis de todos los scripts PowerShell.
- Generación de skin adaptable en español, inglés, modo térmico, módulos ocultos y modo compacto.
- Verificación estática del lanzador sin consola y de los accesos directos generados.
- Prueba aislada del cierre de respaldo sin depender del agente de bandeja.

## Integridad

SHA-256 de `AlienGamerMode-Setup-1.3.5.exe`:

`5C7DAD27D734A59F7CD373662F06E3BD53A8B7E4D6A8CA5CA8B934FF15CD15BB`
