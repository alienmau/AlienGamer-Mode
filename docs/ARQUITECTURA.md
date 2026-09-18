# Arquitectura de mantenimiento

## Flujo de arranque

```text
Agente de bandeja
  ├─ inicia HWiNFO oculto y espera Shared Memory
  ├─ Discover-AlienGamerHardware.ps1
  ├─ Resolve-AlienGamerProfile.ps1
  ├─ Build-AdaptiveSkin.ps1
  ├─ AlienGamerBridge.ps1 (127.0.0.1:27843)
  └─ activa AlienGamerMode en Rainmeter
```

## Contrato de sensores

El lector procesa el encabezado y las tablas publicadas en `Global\HWiNFO_SENS_SM2`. Conserva nombre original, nombre personalizado, unidad, IDs y valores. El resolvedor puntúa coincidencias por:

1. etiqueta original o localizada;
2. unidad;
3. grupo de sensor;
4. GPU o unidad elegida;
5. IDs únicamente como dato de diagnóstico.

El endpoint `/v2/status` devuelve JSON con nombres estables. El endpoint `/` conserva una cadena posicional generada dinámicamente para WebParser de Rainmeter. Su longitud es `14 + procesadores monitorizados`, de modo que ya no existe la deuda técnica de 30/38 campos fijos.

Antes de mostrar la skin se validan la etiqueta canónica, la fuente, la unidad y el rango de cada sensor. Las métricas de juego usan exclusivamente `Framerate Presented (avg)` y `Frame Time Presented (avg)` de PresentMon; además se comprueba que el tiempo de cuadro sea coherente con `1000 / FPS`. El puente repite la validación de rangos y coherencia en cada lectura. Una asociación inexistente, ambigua o incoherente se publica como `N/D`, nunca como cero ni como un estado positivo.

La skin generada se guarda en Unicode UTF-16 LE, formato compatible con Rainmeter para conservar correctamente acentos, signos y textos como `¡EXCELENTE!`, `ATENCIÓN`, `TÉRMICO` y `NÚCLEOS FÍSICOS`.

El reloj matricial declara físicamente las 35 celdas Shape dentro de cada uno de sus seis dígitos. No depende de crear formas durante la ejecución ni únicamente de heredarlas mediante `MeterStyle`. `MatrixClock.lua` sólo cambia posición y color sobre opciones que Rainmeter ya cargó. Este archivo debe conservarse en UTF-8 sin BOM: el intérprete Lua integrado no ejecuta el script cuando encuentra la marca `EF BB BF` al inicio.

El botón OFF tiene cierre redundante: `AlienGamerModeCommand.ps1` escribe una solicitud local y también intenta el evento rápido. El agente recoge cualquiera de las dos vías y ejecuta la misma función `Stop-Monitor` que usa la bandeja, cerrando skin, puente y procesos propios en orden. La solicitud escrita evita perder la orden cuando Rainmeter y el agente tienen niveles de permisos diferentes; la desactivación visual directa queda como respaldo si el agente no responde.

Los botones de la skin ejecutan PowerShell directamente mediante `LeftMouseUpAction`; no dependen del complemento `RunCommand`. El agente consulta el estado visible de Rainmeter y `%LOCALAPPDATA%\AlienGamerMode\recording-state.json` para actualizar la bandeja. La grabación distingue `recording` de `finalizing`, evitando iniciar otra captura mientras se genera o guarda el reporte.

La interfaz se actualiza visualmente a 10 FPS para suavizar las transiciones, pero `HWiNFO_BRIDGE` usa `UpdateRate=10` y las medidas de sensores llevan divisores equivalentes: los datos continúan consultándose una vez por segundo. `MatrixClock.lua` sólo reconstruye los dígitos cuando cambia el segundo. El mismo script interpola el ancho y color del botón Grabar, el hover de OFF y el pulso de opacidad del testigo rojo. Al activar la grabación, el borde derecho permanece fijo y el botón crece 60 unidades de referencia hacia la izquierda para no invadir el margen exterior.

`RingAnimator.lua` crea una medida visual independiente por anillo. Lee el valor relativo validado de la medida fuente y recorre el cambio con interpolación exponencial a 10 FPS; el número continúa enlazado a la medida fuente real. Esto suaviza RAM, VRAM, uso y temperatura de CPU/GPU, almacenamiento, temperatura máxima y procesadores lógicos sin inventar lecturas intermedias como datos de sensores. Cuando GPU/CPU, temperatura máxima o RAM entran en el umbral que ya se representa en rojo, `MatrixClock.lua` modula suavemente brillo y opacidad del trazo. No se aplica alarma roja por una carga alta aislada de un núcleo, pues durante un juego puede ser normal.

El instalador muestra una sola confirmación final y no inicia el agente hasta que esa ventana y el formulario principal se cerraron. PowerShell recibe `-WindowStyle Hidden` para ocultar únicamente la consola; no debe usarse `runhidden` en Inno Setup porque también oculta el formulario WinForms y deja al empaquetador esperando una ventana invisible. El asistente se mantiene al frente. Después se envían dos pulsos idempotentes de activación separados por 1.5 segundos, de modo que la orden no se pierda mientras el agente crea por primera vez su evento local y su icono de bandeja.

La firma `by Alienmau` se renderizó localmente desde Dali como `assets\AlienmauSignature.png` con transparencia y resolución 487 × 192. La skin la muestra a 122 × 48 unidades de referencia, en la misma relación de aspecto y anclada 20 unidades después del título. No se incluye ni instala `dali___.ttf`, porque no se dispone de una licencia explícita de redistribución. El recurso gráfico evita sustituciones tipográficas y conserva nitidez mediante reducción desde una imagen cuatro veces mayor.

El estado activo se determina mediante el PID vivo de `AlienGamerBridge`, porque `Active` en `Rainmeter.ini` puede no reflejar inmediatamente una skin visible. Las zonas de captura de OFF y Grabar se generan al final del archivo, por encima del resto, y usan coordenadas físicas ya escaladas; así el área de ratón coincide con el botón dibujado incluso cuando el diseño usa `TransformationMatrix` por resolución o DPI.

## Diseño adaptable

La referencia visual mide 1711 × 1023. El generador calcula:

```text
escala = min(anchoEfectivoRainmeter / 1711, altoEfectivoRainmeter / 1023)
```

Después centra el lienzo y aplica una matriz a cada elemento. El fondo negro siempre cubre el monitor completo. Los procesadores se reparten en 1 a 4 filas según la cantidad real y reducen su tamaño dentro de límites legibles.

Las dimensiones se obtienen en coordenadas efectivas de Windows, no en píxeles físicos. Esto evita aplicar dos veces el escalado en configuraciones con DPI mixto; por ejemplo, una pantalla física de 2560×1600 al 150 % se entrega a Rainmeter como 1707×1067. La posición se escribe en la configuración persistente y también se fuerza después de activar y refrescar la skin, para impedir que Rainmeter reutilice las coordenadas de otro monitor.

El generador valida que no se pierdan los encabezados `[MeterBackground]`, `[HWiNFO_BRIDGE]` ni los ocho campos posteriores a los procesadores. Así se conserva el contrato dinámico completo de `14 + procesadores monitorizados` y se evitan lecturas literales como `%1` o valores vacíos.

### Fondo ambiental

`BackgroundAnimator.lua` controla hasta 48 medidores de imagen pequeños basados en `ParticleGlow.png`, un degradado radial blanco que Rainmeter tiñe con el color configurado. Por defecto se muestran 26. Cada partícula mantiene estado propio de posición, profundidad, tamaño, velocidad, deriva de dos frecuencias, pulso luminoso y altura de desaparición. En cada nacimiento se asigna una probabilidad del 70% de recorrer hasta el 75% de la altura y del 30% de completar el 100%. El máximo de tamaño anterior se normalizó como la nueva referencia de 100%, ajustable entre 70% y 160%. La animación trabaja a 10 FPS y utiliza `smoothstep` para entradas, salidas y cambios del factor global de tamaño. Los medidores reciben la misma `TransformationMatrix` que la interfaz, por lo que escalan y se centran junto con los módulos.

Las variaciones aleatorias se generan localmente al iniciar. Los cambios de brillo usan objetivos e interpolación progresiva para evitar parpadeos bruscos. Los contenedores usan rellenos oscuros semitransparentes y bordes de baja luminancia para simular cristal ahumado sin depender de complementos externos de desenfoque.

El fondo no consulta la salida de audio. El agente de bandeja persiste `enabled`, `particleCount`, `speed`, `sizeScale` y `color` dentro de `appearance.backgroundEffect`, y actualiza las variables de Rainmeter en vivo. Al desactivarlo, `BackgroundScript` oculta el grupo `AmbientParticles` y deja de calcular trayectorias; conserva únicamente una comprobación mínima de estado para poder reactivarse sin recargar la skin.

Desde 1.3.1 también persiste `mode` (`manual` o `thermal`). En modo térmico, `BackgroundAnimator.lua` consulta únicamente medidas ya validadas de Rainmeter. La severidad global es el máximo normalizado de CPU/Core Max y GPU con sus respectivos umbrales; las banderas térmicas fuerzan rojo crítico. Cada segundo conserva una ventana corta de *frame time*, calcula media y desviación, y combina su fluidez/estabilidad con la actividad CPU/GPU para definir una cantidad objetivo. Velocidad, densidad y RGB se interpolan a 10 FPS con ataque y caída diferentes. El número configurado y la velocidad configurada son límites, no valores que el modo térmico pueda superar.

## Módulos visibles y persistencia

La configuración `features.processorPanelVisible` controla el contenedor, encabezado y medidores de procesadores lógicos agrupados como `ProcessorPanel`. `features.performancePanelVisible` controla el panel flotante completo de FPS, *frame time* y alertas, agrupado como `PerformancePanel`. `features.clock` controla los seis dígitos y separadores agrupados como `ClockPanel`. Los tres valores son `true` por defecto y se administran desde **Módulos visibles** en la bandeja.

En el rango crítico, los anillos de uso de CPU/GPU, RAM y temperaturas de CPU, GPU, núcleo máximo y almacenamiento mantienen opacidad completa. `MatrixClock.lua` produce el destello alternando suavemente entre rojo base `195,0,12` y rojo intenso `255,0,28`; no interpola hacia blanco, rosa ni transparencia.

Al cambiar una opción, el agente guarda primero el JSON del usuario y, si el monitor está activo, actualiza las preferencias del perfil ya validado y regenera la skin sin reiniciar HWiNFO ni el puente de sensores. Esta regeneración conserva correctamente los estados internos de las alertas; al abrir el programa de nuevo, la skin nace ya con los medidores elegidos visibles u ocultos. Los sensores ocultos continúan capturándose en los reportes de eventos.

`features.compactOverlay` activa una vista centrada que conserva únicamente `PerformancePanel`. El generador desplaza el bloque de 900 × 75 unidades al centro del lienzo de referencia antes de aplicar la transformación responsiva. El fondo, encabezado, botones y zonas de captura se ocultan y el control queda en la bandeja.

## Event Intelligence 1.3

`AlienGamerEventRecorder.ps1 -BufferWorker` consulta el puente una vez por segundo y conserva en `%LOCALAPPDATA%\AlienGamerMode\event-prebuffer.json` únicamente las últimas 60 muestras. El agente inicia este trabajador después de validar el puente y lo detiene antes de apagar sus procesos. Una grabación copia el búfer al CSV como fase `Pre-evento` y continúa agregando muestras de fase `Grabacion`.

Cada invocación `-MarkIncident` agrega una marca UTC/local a la sesión. El reporte analiza una ventana configurable antes y después de cada marca. La puntuación de estabilidad combina P95/P99 de *frame time*, proporción de muestras por encima de 33.3 ms, variación relativa, muestras inválidas y alertas térmicas o de potencia. Es una heurística explicable, no un diagnóstico.

El libro contiene `Resumen`, `Cronologia`, `Nucleos`, `Sistema`, `Criterios`, `Incidentes`, `Comparacion`, `Datos_brutos` y `Privacidad`. Un historial local limitado conserva resúmenes para comparar sesiones sin duplicar libros. El asistente de privacidad puede ocultar identificadores del equipo y PID; las lecturas técnicas permanecen para conservar utilidad diagnóstica.

La selección se aplica primero al grupo visual para que ocultar sea perceptible de inmediato y se presenta una ventana temporal de progreso mientras se reconstruye la skin. El perfil reutiliza las asociaciones de sensores ya validadas; no repite el descubrimiento del hardware. El puente trata las solicitudes que Rainmeter cancela durante un refresco como desconexiones normales del cliente, evitando que una actualización visual detenga la fuente de datos o produzca ceros y `N/D` transitorios.

## Localización

`AlienGamer.Localization.psm1` normaliza el idioma y carga los recursos JSON de `src/locales/`. La versión 1.2.0 incluye `es-MX.json` y `en-US.json`. El código consulta claves semánticas como `tray.stopMonitor`, `skin.frameTimeHelp` o `installer.complete`; para añadir otro idioma se crea un archivo con la misma estructura, sin duplicar la lógica del agente o la skin.

Inno Setup muestra siempre su selector de idioma y pasa `{language}` al instalador WinForms. El instalador guarda el código normalizado en `language` dentro de `AlienGamerMode.json`. `Resolve-AlienGamerProfile.ps1` lo copia al perfil validado y `Build-AdaptiveSkin.ps1` genera los textos adecuados conservando UTF-16 LE.

El submenú **Idioma / Language** actualiza el JSON, el perfil y los textos de la bandeja. Cuando la skin está activa se reconstruye y refresca reutilizando las asociaciones de sensores existentes; no reinicia HWiNFO ni el puente. Cuando está detenida, sólo se guarda la preferencia y se aplica en la siguiente activación.

## Clasificación P/E

Windows expone `EfficiencyClass` mediante `GetSystemCpuSetInformation`. Cuando hay varias clases, la superior se trata como rendimiento y las demás como eficiencia. Si Windows no lo distingue, la etiqueta es `CORE`; nunca se inventa P-CORE/E-CORE.

## Protección OLED

- negro puro en toda la ventana;
- desplazamiento cada 120 segundos de sólo el contenido, no de la ventana;
- amplitud de ±2 píxeles;
- el fondo permanece fijo para no revelar una franja del escritorio;
- sin grandes superficies blancas;
- contornos y texto con luminancia contenida.
- partículas y trazadores con brillo limitado, desplazamiento continuo y áreas luminosas pequeñas;
- fondo configurable y desactivable para reducir actividad visual.

El pixel shift reduce la permanencia exacta de elementos, pero no sustituye las funciones de cuidado del panel, salvapantallas ni apagado automático del fabricante.

## Migración a la edición oficial

El instalador usa exclusivamente la identidad `AlienGamerMode`: skin `AlienGamerMode`, puerto local `27843`, datos en `%LOCALAPPDATA%\AlienGamerMode` y programa en `%PROGRAMDATA%\AlienGamerMode\App`. Antes de instalar detiene agentes y tareas anteriores, archiva sus datos y skins en `%LOCALAPPDATA%\AlienGamerModeLegacyBackup`, migra la configuración compatible y retira accesos duplicados.

## Compatibilidad futura

Ante una estructura de memoria HWiNFO desconocida, el lector falla con un mensaje explícito y conserva el inventario/log. No debe adivinar offsets ni convertir ausencia en cero. Una actualización futura puede añadir un adaptador de proveedor sin cambiar el frontend ni el JSON v2.
