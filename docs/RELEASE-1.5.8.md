# AlienGamer Mode 1.5.8 — candidato local de prueba

## Correcciones

- Los recursos Lua y la imagen de partículas se instalan en el `@Resources` raíz que Rainmeter resuelve para todas las vistas multidisplay.
- Se restauran los arcos de color, el reloj matricial, las transiciones de controles y los fondos manual y térmico.
- La compilación se detiene con un error explícito si falta cualquiera de esos recursos visuales.

## Rendimiento y experiencia

- Guardar una distribución reutiliza el perfil de sensores ya validado; no vuelve a analizar todo el inventario de HWiNFO.
- La reconstrucción visual medida pasó de 23–38 segundos a cerca de 1.6 segundos.
- Un aviso `Aplicando cambios…` permanece sobre cada pantalla configurada hasta que la nueva skin queda activada.
- Los cambios de equipo, GPU o SSD conservan la validación completa de sensores y no usan el atajo visual.
- Se eliminó el semicírculo gris que aparecía en `(0,0)` porque una sección de estilo era interpretada como medidor visible.

## Editor multidisplay

- Una instalación puede crear y activar vistas simultáneas en varios monitores.
- Cada pantalla conserva su propia selección de módulos, posiciones, tamaños, diseño predefinido y modo de fondo.
- La previsualización respeta la resolución y proporción real, admite arrastre y redimensionado y bloquea solapamientos o salidas del lienzo.
- El encabezado identificador es obligatorio y fijo; el resto de los módulos se adapta a la finalidad de cada pantalla.
- Las opciones globales redundantes de fondo y módulos se retiraron del menú de bandeja y ahora se gestionan por pantalla desde `Pantallas y distribución...`.

## Próxima entrega

Se documentó la propuesta de panel móvil local: microservicio web desactivado por defecto, acceso mediante QR temporal, módulos configurables por dispositivo y sincronización sin nube.

## Estado

- Candidato local; no publicado en GitHub ni en foros.
- Instalador: `build/installer/AlienGamerMode-Setup-1.5.8.exe`.
- SHA-256: `EC2899C45671D76545162E503C780A5B763B80439578593766E1ECFD36262F55`.
