# Enfoque de pantallas — tema de escritorio

Implementación local aprobada por el usuario. No implica publicación de una nueva versión.

## Dirección y estructura

Tema oscuro de grises neutros, tipografía Segoe UI existente y acento naranja compatible con el icono. Densidad media, animación decorativa nula y controles nativos: no añade frameworks, fuentes ni servicios externos.

- Arriba: tarjetas redondeadas de pantallas físicas y Celular o tablet; selección separada de activación y estado textual Activa/Inactiva. Conserva las pantallas desconectadas sin reasignarlas.
- Centro: vista previa centrada, encabezado fijo, módulos redondeados y selección naranja. Los esquemas de RAM/VRAM no representan lecturas en vivo. Arrastre/redimensionado mantienen la validación de límites y solapamientos.
- Debajo: panel lateral vertical de Módulos, Fondo y Diseño para la misma pantalla seleccionada; botones de 40 píxeles, relleno lateral de 18, separación de 8 y margen de 24 respecto a las opciones. El botón activo lleva fondo gris elevado y texto fuerte, conservando foco naranja independiente.
- Más pantallas: se añaden a la misma sección superior en filas de hasta tres tarjetas; el ancho depende del espacio de la ventana, sin reducir indefinidamente cada tarjeta. La sección crece por filas y, si el alto disponible no alcanza, el contenido tiene desplazamiento vertical con acciones persistentes al pie. Celular o tablet sigue siendo una tarjeta de acceso, no un monitor físico inventado.
- Pie persistente: estado de cambios y acciones Descartar cambios / Guardar y aplicar.

`src/AlienGamer.UI.psm1` y `src/native/AlienGamerTheme.cs` centralizan superficies, texto, acento y estados. El tema alcanza menú de bandeja y submenús, hardware, temporizador, QR, selector RGB, progreso y mensajes de error/confirmación/grabación. No modifica la asignación física de pantallas, sensores, grabaciones, servicio móvil ni preferencias existentes.

## Paleta

| Rol | Valor |
|---|---|
| Ventana | #181818 |
| Superficie | #202020 |
| Control elevado | #2B2B2B |
| Vista previa | #101010 |
| Texto | #EEEEEE |
| Texto secundario | #B8B8B8 |
| Borde | #4C4C4C |
| Acento naranja | #FF9940 |
| Error | #FF9191 |

El acento no reemplaza colores térmicos ni el color de luciérnagas elegido por el usuario. Contraste alto de Windows conserva controles y colores del sistema. Tab/Shift+Tab, Enter y Escape usan navegación nativa; las flechas desplazan módulos de la vista previa en 10 píxeles del monitor, o 1 con Shift, sólo si la ubicación es válida. Los módulos muestran foco separado de selección.

## Validación

- `tests/Test-DesktopTheme.ps1`: compilación Windows PowerShell 5.1, controles, menú/submenú, contraste, selección, diálogo modal y selector RGB; captura del formulario de temporizador sin escribir preferencias.
- Editor `-UiTest`: navegación de pestañas y acciones visibles en ventanas de 1100, 1280 y 1600 píxeles de ancho, usando configuración de prueba.
- `tests/Test-MobileDialog.ps1`: activar, mostrar QR, renovar y desactivar acceso.
- `tests/Test-AlienGamerMode.ps1`: regresiones generales.
- `tests/Test-EnfoqueEditor.ps1`: tarjetas, distribución adaptable, casillas y captura usando dos monitores simulados, sin modificar la instalación.
- `tests/Test-HiddenProcesses.ps1`: procesos sin consola, diagnóstico de errores y códigos de salida conservados. El nuevo lanzador gráfico usa CREATE_NO_WINDOW, no oculta ventanas ajenas.

Las pruebas de escalado son simulaciones de contenedores; no sustituyen revisar Windows en DPI real 125%, 150% y 200%. El marco no cliente que dibuja Windows puede variar según versión/compositor. UAC, globos del sistema y el explorador nativo para guardar informes conservan su apariencia de Windows.
