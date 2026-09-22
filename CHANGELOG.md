# Historial de cambios

## 1.5.9 — 22 de septiembre de 2026

- Corrige los aros grises duplicados que podían aparecer sobre RAM, uso del sistema y temperaturas después de instalar 1.5.8.
- Conserva la eliminación del semicírculo residual de la esquina superior izquierda sin activar los contornos auxiliares de Rainmeter.
- Añade una prueba de regresión que impide que `BG2Style` o cualquiera de sus siete bloques auxiliares vuelva a convertirse en un medidor visible.

## 1.5.8 — 21 de septiembre de 2026

- Corregida la ruta de recursos compartidos de Rainmeter en vistas multidisplay; vuelven a funcionar los arcos animados, el reloj matricial y el fondo de luciérnagas.
- La compilación ahora valida que `RingAnimator.lua`, `MatrixClock.lua`, `BackgroundAnimator.lua` y `ParticleGlow.png` existan en el `@Resources` raíz antes de activar la skin.
- Los cambios exclusivos de distribución, fondo o idioma reutilizan el perfil HWiNFO previamente validado, evitando repetir el análisis completo de sensores.
- El tiempo medido de reconstrucción visual se redujo de 23–38 segundos a aproximadamente 1.6 segundos en el equipo de validación.
- Mientras se aplica una distribución se muestra un aviso bilingüe y visible sobre cada pantalla configurada.
- Eliminado un medidor de estilo que Rainmeter dibujaba como un semicírculo gris residual en la esquina superior izquierda.
- Incorporada una exportación verificable del editor para mantener actualizadas las capturas de documentación.

## 1.5.7 — 21 de septiembre de 2026

- Cada instalación inicia desde la configuración oficial limpia, con el diseño completo y todos los módulos visibles.
- Respalda el JSON anterior en `AlienGamerModeLegacyBackup` y conserva intactas las grabaciones y los reportes.
- Elimina perfiles, skins generadas, manifiestos y trazas obsoletas antes de crear la nueva distribución.
- Separa la aplicación crítica de la notificación de bandeja para que una notificación ausente no convierta un guardado válido en error.
- Valida el código de salida de la reconstrucción y registra cada etapa en `agent-diagnostic.log`.
- Al fallar, identifica la etapa exacta en lugar de mostrar solamente una expresión nula.

## 1.5.6 — 20 de septiembre de 2026

- Corrige la excepción que aparecía después de **Guardar y aplicar**, incluso al cambiar únicamente el fondo a dinámico térmico.
- Protege el ciclo del agente que detecta el cierre del editor, reconstruye las skins y actualiza la bandeja; un fallo ya no puede escapar como cuadro genérico de .NET.
- Añade captura global de excepciones de la interfaz y una traza por etapas en `%LOCALAPPDATA%\AlienGamerMode\layout-editor.trace.log`.
- Genera el símbolo de redimensionado en tiempo de ejecución para evitar `â†˜` y otros caracteres corruptos en Windows PowerShell 5.1.
- Valida el guardado usando una copia exacta de una configuración personalizada existente y otra con fondo térmico.

## 1.5.5 — 20 de septiembre de 2026

- Corrige el fallo posterior a **Guardar y aplicar** causado al intentar escribir el error original en una consola no disponible.
- Sustituye la salida de consola por un registro UTF-8 fiable en `%LOCALAPPDATA%\AlienGamerMode\layout-editor.error.log`.
- Deshabilita **Guardar y aplicar** mientras exista una distribución inválida e identifica la pantalla y los módulos en conflicto.
- Verifica el evento real del botón de guardado, la escritura de la configuración y el cierre correcto del formulario.

## 1.5.4 — 20 de septiembre de 2026

- Corrige el error de guardado que restauraba internamente los tamaños base y producía falsos solapamientos o expresiones nulas.
- Conserva correctamente el estado **Personalizado** y las dimensiones elegidas al mover o redimensionar cualquier módulo.
- Recalcula el diseño completo para que rendimiento y procesadores no se crucen en pantallas 2048×1280.
- Oculta los controles OFF/grabación en los diseños **Esencial horizontal** y **Esencial vertical**.
- Centra el encabezado fijo en el diseño vertical y distribuye RAM, VRAM, uso y temperaturas dentro del alto disponible.
- Amplía y estabiliza el control de redimensionado para no perder el arrastre al salir del tirador.
- Retira el menú global **Fondo** de la bandeja; cada pantalla administra su fondo desde **Pantallas y distribución...**.
- Añade validaciones automáticas de límites, margen y solapamiento para 2048×1280, 2560×1440 y 1080×1920.

## 1.5.3 — 20 de septiembre de 2026

- Rediseña **Pantallas y distribución...** con una previsualización basada en la proporción y resolución reales de cada monitor.
- Permite mover y redimensionar libremente los módulos opcionales, sin rejilla fija y con escala proporcional.
- Impide que los módulos se solapen, salgan de la pantalla o pierdan el margen mínimo de separación.
- Mantiene el encabezado siempre visible, fijo en la esquina superior izquierda y fuera de la lista de módulos opcionales.
- Aplica los diseños predefinidos inmediatamente en la previsualización; la skin real sólo cambia con **Guardar y aplicar**.
- Añade por pantalla los controles manuales de cantidad, velocidad, tamaño y color del fondo; el modo térmico conserva parámetros automáticos.
- Retira el menú rápido **Módulos visibles**, ambiguo al configurar varias pantallas, y deja el editor como fuente única de distribución.
- Corrige la excepción de .NET causada por expresiones nulas y encapsula las acciones del editor para presentar errores controlados.
- Centraliza los textos del editor en archivos UTF-8 de idioma para conservar correctamente acentos y caracteres en español.

## 1.5.2 — 20 de septiembre de 2026

- Corrige el editor **Pantallas y distribución...** que podía ejecutarse oculto al intentar esconder la consola de PowerShell.
- Oculta únicamente la consola auxiliar y mantiene visible, centrada y operativa la ventana gráfica del editor.
- Libera automáticamente la opción del menú si el editor no llega a publicar una ventana, evitando que quede deshabilitada después de usar **OFF** y volver a activar el monitor.
- Después de cualquier instalación, abre el editor tras iniciar el monitor para elegir o confirmar módulos, pantallas y posiciones.
- Conserva sin cambios las distribuciones creadas previamente por cualquier versión 1.5.
- Solicita el cierre cooperativo del agente anterior antes de actualizar archivos, reduciendo procesos residuales durante la instalación.

## 1.5.1 — 20 de septiembre de 2026

- Corrige la actualización desde esquema 2: una instalación 1.4 inicia con una distribución multidisplay limpia y coherente, sin mezclar `features` antiguos con visibilidad por pantalla.
- Conserva idioma, monitor, GPU, SSD y ajustes compatibles, pero restablece únicamente reloj, procesadores, rendimiento y modo compacto para que el usuario los configure bajo el nuevo esquema.
- El agente también detecta y repara configuraciones 1.4 que hayan sobrevivido a una instalación 1.5.0 incompleta.
- El estado del menú **Módulos visibles** se obtiene de la primera vista habilitada, que es la misma fuente usada para dibujar la skin.
- **Pantallas y distribución...** se abre en un proceso no bloqueante; la bandeja continúa respondiendo y aplica los cambios al cerrar el editor.
- Los errores del editor quedan en `layout-editor.error.log` y se presentan de forma visible en lugar de dejar un proceso congelado sin explicación.

## 1.5.0 — 20 de septiembre de 2026

### Nuevas funciones

- Añade **Pantallas y distribución...**, un editor visual para activar varias pantallas locales y arrastrar cada módulo a una posición independiente.
- Permite mostrar u ocultar encabezado, reloj, controles, RAM, VRAM, uso CPU/GPU, temperaturas, FPS/alertas y procesadores por cada pantalla.
- Incorpora diseños predefinidos completo horizontal, esencial horizontal, esencial vertical, sólo rendimiento y sólo temperaturas.
- Permite activar el fondo y elegir modo personalizado o térmico de manera independiente por pantalla.

### Arquitectura y persistencia

- Genera una configuración Rainmeter aislada en `AlienGamerMode\\Views\\<vista>` por cada pantalla habilitada.
- Todas las vistas comparten una sola instancia validada de HWiNFO, el puente local, el búfer previo y la grabación; no se duplican consultas de sensores.
- Guarda posiciones, visibilidad, pantalla física, lienzo, preset y fondo en el nuevo esquema de configuración 3.
- Migra la pantalla elegida y las preferencias existentes de versiones anteriores sin exigir reinstalación limpia.

### Correcciones

- El pixel shift OLED conserva los desplazamientos personalizados de cada módulo en lugar de restablecerlos periódicamente.
- Grabar y marcar incidente identifican la vista Rainmeter que originó la acción y sincronizan el estado en todas las pantallas.
- Los cambios de idioma, fondo y módulos reconstruyen todas las vistas activas sin reiniciar el puente de sensores.

## 1.4.0 — 19 de septiembre de 2026

### Nuevas funciones

- Genera automáticamente un reporte visual HTML al finalizar cada grabación, junto al libro de Excel y al CSV de datos brutos.
- El reporte funciona sin conexión, es responsivo, imprimible y puede abrirse en cualquier navegador moderno sin instalar componentes adicionales.
- Incluye resumen ejecutivo, puntuación de estabilidad, métricas principales, cronologías independientes de FPS y *frame time*, temperaturas, uso del sistema, incidentes y contexto técnico.
- Conserva las etiquetas de incidentes y ofrece enlaces relativos al Excel y CSV complementarios.

### Mejoras

- Separa FPS y *frame time* en gráficas con escalas propias para evitar comparaciones visuales engañosas.
- Protege identificadores del equipo en el reporte visual cuando se activa el asistente de privacidad.
- Completa la presentación en español e inglés y corrige acentos en clasificaciones, evidencias e interpretaciones.
- Mantiene el HTML y CSV disponibles incluso si Excel no está instalado o falla la creación del libro.

### Correcciones incluidas

- Corrige el error de conversión de fechas al finalizar grabaciones sin incidentes o con datos pendientes de una versión anterior.
- Evita consolas de PowerShell visibles durante el arranque, OFF y las acciones de la skin.
- OFF aplica un cierre de respaldo si el agente no responde y detiene Rainmeter, HWiNFO, el puente y el búfer sin acumular ventanas vacías.

## 1.3.5 — 19 de septiembre de 2026

- Ejecuta el agente permanente mediante Windows Script Host, sin una consola de PowerShell visible que pueda cerrarse accidentalmente.
- Los accesos directos, el inicio con Windows y el primer arranque posterior a la instalación usan el mismo lanzador silencioso.
- OFF y Grabar ya no crean ventanas de PowerShell desde la skin.
- Reduce de 45 a 3 segundos la espera máxima de OFF y añade una limpieza independiente si el agente no responde.
- El cierre de respaldo detiene la skin, el puente, el búfer, Rainmeter, HWiNFO y su tarea elevada, y corrige el estado persistente.
- OFF cierra Rainmeter incluso si una ejecución anterior dejó obsoleto el indicador interno de propiedad.

## 1.3.4 — 18 de septiembre de 2026

- Valida y descarta de forma segura las fechas vacías o inválidas del búfer previo de eventos.
- Al actualizar, detiene cualquier proceso de grabación o búfer que aún conserve una versión anterior del código en memoria.
- Conserva el CSV de una grabación interrumpida y elimina únicamente sus archivos temporales de control.
- Evita que una actualización finalice una captura con código obsoleto y muestre nuevamente el error de conversión `DateTime`.

## 1.3.3 — 18 de septiembre de 2026

- Corrige la generación del reporte cuando una grabación termina sin incidentes marcados.
- Las listas de incidentes vacías y las fechas inválidas se omiten de forma segura, sin perder la captura CSV.
- Mantiene intactos los datos pendientes si Excel no puede completar el reporte.

## 1.3.2 — 18 de septiembre de 2026

- Identifica cada pantalla por su identidad física PnP, no solamente por nombres inestables como `DISPLAY1` o `DISPLAY11`.
- Reafirma discretamente la posición de la skin para que un juego abierto previamente no la desplace al monitor principal.
- Añade **Configurar equipo y pantalla...** a la bandeja para cambiar monitor, GPU y almacenamiento sin reinstalar.
- Separa por completo los modos de fondo: los controles de luciérnagas solo están disponibles en **Personalizado**; **Dinámico térmico** usa límites propios.
- El modo térmico reduce progresivamente cantidad y velocidad cuando la GPU supera el umbral de protección o empeora el *frame time*.
- Conserva transiciones suaves al entrar o salir de protección para evitar cambios visuales bruscos.

## 1.3.1 — 17 de septiembre de 2026

- Añade el submenú persistente **Fondo** con los modos **Desactivado**, **Personalizado** y **Dinámico térmico**.
- El modo térmico toma el color del estado global más exigente entre CPU, núcleo máximo y GPU; una alerta de *thermal throttling* fuerza el estado crítico.
- La cantidad de luciérnagas responde a la fluidez y estabilidad reciente de *frame time*, combinadas con la actividad real de CPU/GPU.
- La velocidad responde a la actividad del equipo y respeta como límite la calibración elegida por el usuario.
- Incorpora transiciones diferenciadas de subida y bajada para evitar cambios bruscos de densidad, velocidad y color.
- Mantiene validación de sensores: si FPS, temperatura o carga no existen, usa únicamente lecturas válidas y una actividad visual segura.
- Conserva el modo personalizado, los límites de 8–48 partículas, la protección OLED y el funcionamiento local sin captura de audio.

## 1.3.0 — 17 de septiembre de 2026

- Añade **Event Intelligence** con un búfer circular de 60 segundos previo al inicio de la grabación.
- Permite marcar uno o varios incidentes durante la captura y analiza una ventana temporal alrededor de cada marca.
- Incorpora una puntuación de estabilidad de 0 a 100 basada en percentiles de *frame time*, picos, variación, muestras inválidas y alertas térmicas o de potencia.
- El reporte incluye interpretación y recomendación preliminares con evidencia y una advertencia expresa: no constituyen un diagnóstico concluyente.
- Añade hojas de incidentes, comparación con la sesión anterior, datos brutos y privacidad; también puede guardar un CSV bruto junto al libro.
- Agrega un asistente de privacidad que puede ocultar identificadores del equipo y PID antes de compartir el reporte.
- Añade **Modo compacto FPS**, que deja únicamente FPS, *frame time* y alertas, centrados en cualquier resolución.
- Conserva las mejoras 1.2.0 de interfaz español/inglés y el cierre coordinado del botón **OFF**.

## 1.2.0 — 15 de septiembre de 2026

- Añade español (`es-MX`) e inglés (`en-US`) mediante recursos de traducción centralizados.
- Permite elegir el idioma desde el diálogo inicial de Inno Setup y conserva la selección en la configuración del usuario.
- Incorpora **Idioma / Language** en el menú de bandeja para cambiar la skin y el agente sin reiniciar HWiNFO ni el puente de sensores.
- Traduce los textos del monitor, estados de frame time, ayudas, botones, menús, configurador de luciérnagas, avisos principales y diálogos de grabación.
- Mantiene español como idioma predeterminado y permite agregar idiomas futuros sin duplicar la lógica del monitor.
- Añade documentación principal en inglés.

## 1.1.1 — 15 de septiembre de 2026

- Corrige el botón **OFF** de la skin para que ejecute el mismo cierre coordinado que **Detener monitor** en el icono de bandeja.
- Añade un canal local persistente como respaldo cuando Rainmeter y el agente se ejecutan con niveles de permisos distintos.
- El apagado desde la skin detiene el puente, finaliza HWiNFO y Rainmeter cuando fueron iniciados por AlienGamer Mode, actualiza el estado y sincroniza el menú de bandeja.
- Mantiene el evento rápido existente y agrega confirmación de que el agente procesó la solicitud.

## 1.1.0 — 11 de septiembre de 2026

- Añade el submenú persistente **Módulos visibles** para mostrar u ocultar procesadores, el bloque flotante de FPS y alertas, y el reloj.
- Los tres módulos permanecen activos por defecto en instalaciones nuevas; ocultarlos no excluye sus datos de las grabaciones técnicas.
- Evita que una solicitud cancelada durante el refresco de Rainmeter cierre el puente y deje sensores en cero o `N/D`.
- Muestra progreso al aplicar módulos, oculta inmediatamente y reutiliza el perfil validado para reducir la espera.
- Incorpora el reloj a **Módulos visibles** y conserva su selección entre sesiones.
- Cambia las alarmas críticas de uso y temperatura a un pulso sólido entre rojo base y rojo intenso, incluyendo la temperatura del almacenamiento.

- Sustituye ondas, malla y trazadores por partículas radiales ascendentes.
- Cada luciérnaga varía en tamaño, profundidad, velocidad, deriva, pulso y altura de desaparición.
- Elimina por completo el análisis y la reacción al audio.
- Agrega a la bandeja activación independiente y un panel con controles de cantidad, velocidad, tamaño y color.
- Distribuye el recorrido: 70% puede cubrir hasta el 75% de la altura y 30% completa el 100% hasta el borde superior.
- Convierte el tamaño máximo anterior en la nueva referencia base de 100%, ajustable entre 70% y 160%.
- Aumenta la transparencia de los contenedores para integrar visualmente el fondo.
- Define límites seguros de 8 a 48 partículas y conserva el escalado responsivo y la protección OLED.

- Contenedores de cristal ahumado semitransparente y contraste controlado.
- Parámetros nuevos incorporados automáticamente a configuraciones anteriores.

## 1.0.9 — Primera versión pública

- Detección adaptable de hardware, monitor, GPU y almacenamiento.
- Skin responsiva para diferentes resoluciones y escalas DPI.
- RAM, VRAM, CPU, GPU, temperaturas, FPS, *frame time* y carga por núcleo.
- Procesadores dinámicos: sensores ausentes se ocultan sin crear valores falsos.
- Validación de identidad, fuente, unidad, rango y coherencia de sensores.
- Indicadores de límite térmico y de potencia.
- Reloj digital tipo matriz.
- Transiciones suavizadas, pulsos críticos y protección para pantallas OLED.
- Grabación de eventos con reporte técnico en Excel.
- Agente de bandeja con controles sincronizados.
- Instalador gráfico y reparación automatizada de HWiNFO Shared Memory.
