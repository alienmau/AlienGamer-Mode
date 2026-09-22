# AlienGamer Mode 1.5.5 — candidato local de prueba

Esta compilación reemplaza los candidatos 1.5.3 y 1.5.4. Corrige el guardado del editor **Pantallas y distribución...** y elimina la ruta que podía mostrar una excepción genérica de .NET. Todavía no se ha publicado.

## Correcciones principales

- Los tamaños del usuario permanecen intactos al guardar.
- El botón **Guardar y aplicar** sólo se habilita cuando todas las pantallas activas tienen una geometría válida.
- Si existe un conflicto, el editor identifica la pantalla y los módulos implicados.
- Los errores se escriben en un archivo UTF-8 y nunca dependen de una consola visible u oculta.
- Los diseños predefinidos respetan límites, margen y separación en 16:9, 16:10 y orientación vertical.
- **Esencial horizontal** y **Esencial vertical** no muestran controles OFF/grabación.
- **Esencial vertical** centra el encabezado y ajusta los cuatro módulos esenciales al alto disponible.
- **Sólo rendimiento** y **Completo horizontal** guardan sin errores de geometría.
- El fondo se configura exclusivamente por pantalla.

## Validaciones automatizadas

- Guardado correcto de los cinco presets.
- Persistencia de una distribución personalizada con RAM reducida de 577×584 a 415×420.
- Validación geométrica en 2048×1280, 2560×1440 y 1080×1920.
- Ejecución del evento real de **Guardar y aplicar**, escritura del JSON y cierre con código 0.
- Generación de skins, idiomas y Event Intelligence.

## Estado de publicación

- GitHub: no publicado.
- Foros: no publicado.
- Instalador local: `build/installer/AlienGamerMode-Setup-1.5.5.exe`.
- Tamaño: 5.15 MB.
- SHA-256: `81DAF182876D03ACDDDECD98D6B84F691BB3808DA22AFD3BE76BA1E64A1C697F`.
- Pruebas automatizadas: superadas.
