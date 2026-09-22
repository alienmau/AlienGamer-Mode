# AlienGamer Mode 1.5.6 — candidato local de prueba

Esta compilación corrige el ciclo completo de **Guardar y aplicar** del editor **Pantallas y distribución...**. Todavía no se ha publicado.

## Correcciones principales

- El agente controla de forma segura el cierre del editor y la reconstrucción de las skins.
- Cambiar sólo el fondo manual/térmico ya no puede producir una excepción no controlada.
- Mover o redimensionar un módulo conserva el diseño personalizado y guarda la configuración.
- El símbolo amarillo de redimensionado se genera como Unicode en tiempo de ejecución y ya no aparece como caracteres extraños.
- Las excepciones de eventos WinForms quedan capturadas y registradas con su detalle real.
- La traza `layout-editor.trace.log` permite comprobar las etapas abrir, guardar, escribir y cerrar.

## Validaciones automatizadas

- Guardado con una copia exacta de la configuración personalizada del equipo de prueba.
- Guardado de esa misma configuración cambiando el fondo a dinámico térmico.
- Generación de skins y validación de presets, geometría, idiomas y Event Intelligence.
- Cierre del editor con código 0 tras escribir correctamente el JSON.

## Estado de publicación

- GitHub: no publicado.
- Foros: no publicado.
- Instalador local: `build/installer/AlienGamerMode-Setup-1.5.6.exe`.
- Tamaño: 5.15 MB.
- SHA-256: `25FDBEBBD7C288E54F16F3B3921B07AF15013A4E0933D35BE59AA890B94CFB76`.
- Pruebas automatizadas: superadas.
