# Panel móvil local (1.7.0)

## Uso

1. Activa el monitor desde AlienGamer Mode.
2. Abre **Pantallas y distribución → Celular o tablet**, en la sección superior de tarjetas de pantallas.
3. Marca **Activar monitor web en mi red local**. El servicio se activa automáticamente y aparecen el enlace y el QR. Para cambiar la selección de módulos, pulsa **Aplicar módulos**.
4. Escanea el QR desde un teléfono o una tableta conectados al mismo router. La laptop puede estar por Ethernet y el dispositivo portátil por Wi-Fi.
5. **Expandir** requiere un toque; **Salir** abandona la pantalla completa sin apagar el monitor de la laptop. La disponibilidad de pantalla completa depende del navegador. Chrome puede mostrar un aviso propio con el origen (dirección) al entrar; la página no puede modificarlo ni ocultarlo.

El panel responde en vertical y horizontal con un encabezado compacto. El diseño base coloca reloj matricial, rendimiento, alertas, tarjetas individuales de RAM, VRAM, GPU y CPU, y un bloque conjunto de temperaturas. Los anillos SVG muestran los valores al centro y conservan colores y umbrales del skin; datos ausentes muestran `N/D`. El fondo de luciérnagas es decorativo y no depende de la temperatura.

## Editar desde el celular o tablet

- Pulsa **Editar**. Usa **Mover** para arrastrar una tarjeta, o las flechas para subirla/bajarla en el orden.
- Las casillas permiten ocultar/restaurar cada tarjeta habilitada para la vista web desde la laptop. CPU y GPU se pueden ocultar por separado; temperaturas se conserva como bloque.
- El selector ofrece **Mínimo** (1 columna), **Normal** (ancho base por módulo) y **Extendido** (fila completa). RAM, VRAM, CPU y GPU tienen base de 1 columna; reloj, **FPS y tiempo de cuadro**, alertas, temperaturas, temporizador y procesadores usan 2. Hay 2 columnas por debajo de 560 px, 4 desde 560 px y 6 desde 1000 px. FPS y alertas normales ocupan todo el ancho de una vista estrecha de dos columnas; al girar conservan las dos unidades, no necesariamente toda la fila.
- La distribución tipo **masonry** coloca cada tarjeta en el grupo de columnas contiguas con menor altura acumulada. Usa el alto natural, sin fijar alturas uniformes: un bloque puede empezar justo debajo de otro más corto aunque la columna vecina continúe ocupada. Conserva el orden de procesamiento, del documento y del teclado; las posiciones visuales pueden intercalarse entre columnas. Extendido actúa como separador: ocupa toda la fila y los módulos posteriores quedan abajo. Se recalcula al girar, editar o variar la altura del contenido mediante ResizeObserver; no depende de CSS masonry experimental ni carga librerías desde Internet.
- FPS y tiempo de cuadro son un único módulo configurable; alertas continúa separado. El selector de la laptop refleja la misma agrupación, y se admiten las configuraciones anteriores del servicio.
- Tarjetas translúcidas con gradiente, borde suave y desenfoque de fondo (glassmorphism), con fondo translúcido de respaldo si el navegador no admite desenfoque. Los títulos se centran; reloj conserva fondo transparente. **Editar → Color de las luciérnagas** cambia el color decorativo y lo guarda sólo en ese navegador, sin alterar los colores de los sensores ni Rainmeter.
- Pulsa **Listo** para volver al monitor; los cambios se guardan automáticamente en `localStorage`, por navegador/dispositivo y se conservan al girar, sin alterar Rainmeter. **Restablecer** recupera el diseño base y el verde de las luciérnagas. Las preferencias v2/v3 se migran al formato compartido v4; FPS y tiempo de cuadro se fusionan, conservando la tarjeta visible si alguna de las dos partes estaba visible.
- Borrar los datos del navegador elimina estas preferencias. Una dirección IP o puerto distintos cambian el origen del navegador y, por tanto, su almacenamiento. Si el navegador bloquea el almacenamiento, la página avisa y permite editar durante la sesión.
- Con muchos módulos o tarjetas grandes se permite desplazamiento vertical. No se recortan tarjetas ni se reduce el texto hasta hacerlo ilegible para forzar todo a caber en una sola pantalla.
- Las luciérnagas se dibujan a un máximo de 20 FPS y con densidad de píxel limitada. Se respeta la preferencia de movimiento reducido y se pausa el dibujo en segundo plano.

## Mantener la pantalla encendida

En **Editar → Mantener pantalla encendida**, activa la opción con un toque. Está desactivada inicialmente y no se recuerda tras recargar: es una decisión por sesión porque consume batería. No requiere entrar en pantalla completa.

La página usa exclusivamente Screen Wake Lock cuando está disponible en un contexto seguro. El enlace HTTP a la IP LAN no cumple ese requisito: la casilla queda deshabilitada y explica que requiere HTTPS confiable. Un navegador sin la API también muestra la opción deshabilitada. Sólo aparece «Activa: permiso concedido» después de obtener realmente el permiso; un rechazo o liberación visible desmarca la casilla.

Se libera al desactivar, salir de la página o pasar a segundo plano; se intenta recuperar al volver. El usuario aún puede bloquear el dispositivo manualmente. Se retiró la alternativa de vídeo tras el reporte de que no evita el bloqueo en un Samsung S26 Ultra con Chrome/Samsung Internet. No se han instalado certificados ni cambiado la seguridad del teléfono; HTTPS local aún no está implementado. Las pruebas automatizadas verifican permiso, liberación, rechazo y opción deshabilitada en HTTP/navegadores sin API, no el bloqueo físico del teléfono. Esta capacidad no se promete para cualquier dispositivo.

Referencia: [Screen Wake Lock de Chrome](https://developer.chrome.com/docs/capabilities/web-apis/wake-lock).

## Privacidad y ciclo de vida (servicio LAN)

- El servicio está **desactivado por defecto** y se ejecuta dentro del puente de sensores existente; no abre un PowerShell adicional.
- Escucha en la IP privada de una interfaz con salida al router, no en `0.0.0.0`, usando TCP 27844. El puerto 27843 permanece reservado a Rainmeter en `127.0.0.1`.
- La regla de firewall del instalador permite sólo TCP 27844 desde `LocalSubnet`, incluida una conexión Ethernet clasificada como Pública. No se configura el router ni se abre acceso por Internet.
- El enlace contiene un código aleatorio de 192 bits. Sin él, las rutas móviles responden 404. La página sólo consulta datos: no permite iniciar/detener grabación ni cerrar HWiNFO o Rainmeter.
- **Nuevo QR** sustituye el código anterior automáticamente. Desmarcar **Activar monitor web en mi red local** cierra el puerto móvil. Al cerrar el puente también desaparece el acceso.
- **Copiar enlace** sólo está habilitado cuando existe un enlace listo y confirma que se copió. La ventana muestra el estado de arranque y avisa si el servicio no responde. El servidor usa la IP LAN de la laptop: `localhost` en un celular señalaría al propio celular, no a la laptop.
- El enlace no debe compartirse fuera de la red de confianza. Se transmite por HTTP local; una red compartida no confiable puede observar tráfico. No se debe usar en redes públicas/aisladas ni configurar reenvío de puertos.
- Cuando HWiNFO no está disponible, los valores se muestran como no disponibles, no como cero real.
- QRCoder 1.8.0 se distribuye bajo MIT; su licencia se incluye en `assets/QRCoder.LICENSE.txt`.

## Cortes de energía y cambios de pantalla

La identidad PnP del monitor se compara antes de aplicar un diseño. Si el ASUS deja de estar conectado, su vista no se mueve a la laptop aunque Windows cambie los números `DISPLAY1/DISPLAY2`. Al volver la energía, abre el editor y comprueba qué pantalla está activa. Al pasar de corriente a batería la bandeja avisa de inmediato y registra el cambio. La app no puede predecir un apagón ni evitar que el juego pierda Internet, pero sí evita una reasignación visual silenciosa. Los eventos de cambio de alimentación de Windows por sí solos no prueban la causa del problema del juego.

## Validación realizada y cobertura pendiente

`tests/Test-AlienGamerMode.ps1` comprueba el proyecto. `tests/Test-MobileDashboard.ps1 -Live` verifica QR, página, datos y rechazo de un enlace sin código desde la laptop. `tests/Test-MobileLayout.cjs` verifica el navegador con ocho tamaños entre 320×568 y 1920×1080, orientación, cada tamaño de tarjeta, ausencia de desbordamiento, texto dentro de los anillos, edición persistente, arrastre y pantalla completa.

El usuario confirmó acceso Wi-Fi ↔ Ethernet desde Chrome móvil y aportó capturas del nuevo diseño en ambas orientaciones y del editor móvil. Queda pendiente probar tablet/iOS reales y compatibilidad en más equipos. No confundir pruebas de navegador en escritorio con pruebas físicas en todos los dispositivos.
