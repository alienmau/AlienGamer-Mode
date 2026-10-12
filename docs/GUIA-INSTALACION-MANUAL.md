# Instalación y prueba manual

## Identidad de la edición oficial

AlienGamer Mode usa:

- skin `AlienGamerMode`;
- puerto local `27843`;
- datos en `%LOCALAPPDATA%\AlienGamerMode`;
- acceso `Activar AlienGamer Mode`.

El instalador sustituye las ediciones anteriores, migra la selección de monitor, GPU y unidad cuando existe, y conserva un respaldo en `%LOCALAPPDATA%\AlienGamerModeLegacyBackup`.

## Instalación

1. Instala HWiNFO64 desde su sitio oficial. Rainmeter también se necesita para vistas de escritorio, pero es opcional en modo sólo móvil.
2. Cierra HWiNFO para que su archivo de configuración no sea reescrito mientras se prepara.
3. Ejecuta `installer\Install-AlienGamerMode.ps1`.
4. Selecciona **Pantallas del equipo**, **Sólo celular/tablet** o **Ambos**, GPU y unidad principal. El monitor físico sólo se elige para vistas de escritorio.
5. Elige Escritorio, menú Inicio e inicio con Windows.
6. Pulsa **Instalar y configurar**.
7. Espera la ventana de preparación. El primer arranque descubre sensores, genera el perfil y adapta el diseño.

En modo móvil se abre el acceso por QR al finalizar. PC y celular/tablet deben compartir router; Ethernet y Wi-Fi pueden funcionar juntos. La instalación completa respalda y reinicia el diseño de escritorio/temporizador, conservando reportes, grabaciones, preferencias móviles e identidad HTTPS de la misma cuenta.

El instalador registra `AlienGamerMode-HWiNFO`, una tarea que inicia HWiNFO con privilegios suficientes para publicar Shared Memory sin solicitar UAC en cada arranque. Las tareas obsoletas se retiran durante la migración.

## Icono de bandeja

Mientras el agente está abierto, el logotipo aparece en los iconos ocultos de Windows. Su menú ofrece:

- Activar monitor / Detener monitor, según el estado real;
- Grabar evento / Finalizar grabación / Finalizando reporte, según la captura;
- Configurar hardware (GPU/almacenamiento);
- Pantallas y distribución (vistas físicas y móvil);
- Temporizador de sesión (tiempo, alarma, MP3 y salida de audio);
- Herramientas → Editar archivo de configuración, con advertencia y respaldo;
- Abrir registros y reportes;
- Cerrar AlienGamer Mode.

**Detener monitor** y el botón **OFF** desactivan la skin, detienen el puente, el búfer y los procesos de presentación/sensores asociados, pero conservan el agente en la bandeja para poder activar el monitor nuevamente. **Cerrar AlienGamer Mode** también retira el agente. El agente funciona en segundo plano mediante Windows Script Host: no debe aparecer una consola de PowerShell permanente. Si existe una grabación, se finaliza antes de detener el monitor. OFF espera hasta doce segundos y ejecuta el cierre de respaldo si sigue activo alguno de los procesos del monitor.

## Grabar evento

Usa **Grabar evento** justo cuando notes tirones, congelamientos, saltos, teletransportes, caídas de FPS o una respuesta anormal del juego. Durante la captura el control cambia a **Finalizar grabación** y el testigo rojo indica que se están tomando muestras.

La versión 1.3.0 incluye automáticamente los 60 segundos previos. Si el síntoma vuelve a ocurrir durante la captura, abre el icono de bandeja y selecciona **Marcar incidente ahora**. Puedes crear varias marcas. Al finalizar, elige si deseas un reporte protegido para compartir y después selecciona dónde guardar el libro.

### Fondo personalizado o térmico

Desde **Pantallas y distribución**, selecciona la pantalla y el panel **Fondo**. El modo personalizado permite cantidad, velocidad, tamaño y color mediante arcoíris, vista previa y brillo. El modo térmico usa temperaturas válidas de CPU/Core Max y GPU, y reduce su carga si detecta saturación de GPU o pérdida de fluidez; sus controles manuales permanecen deshabilitados.

### Cambiar equipo o pantalla sin reinstalar

Usa **Configurar hardware** para GPU y unidad principal, y **Pantallas y distribución** para las salidas físicas/móviles. La pantalla se guarda mediante su identidad física para resistir cambios de numeración de Windows. Puedes desactivar todas las vistas físicas si el monitor móvil está activo.

Consulta la [guía HTTPS móvil](MOBILE-HTTPS-GUIDE.md) y la [guía del temporizador y sus alarmas](MOBILE-TIMER-AUDIO.md). En móvil, un mismo icono **Configurar** reúne tiempo y sonido. No ignores avisos rojos del certificado; verifica que la conexión sea segura.

Conserva juntos el archivo `-visual.html`, el `.xlsx` y el archivo `-datos-brutos.csv`. Puedes analizarlos manualmente, enviarlos a un técnico o pedir a una IA que busque correlaciones, recordando que el resumen es preliminar y no representa una verdad absoluta.

Al finalizar, el programa solicita una ubicación y genera automáticamente un reporte visual HTML, un libro de Excel y un CSV bruto. El HTML reúne un resumen ejecutivo, la puntuación de estabilidad y gráficas separadas de FPS, *frame time*, temperaturas y utilización. El libro añade la cronología detallada, carga por procesador lógico, máximos, percentiles, procesos activos, comparación e interpretación preliminar.

Este documento puede ayudar a relacionar el momento exacto del problema con calentamiento, saturación, *throttling*, límites de potencia o inestabilidad del tiempo de cuadro. Resulta útil para que un técnico investigue con más contexto y para detectar tendencias antes de que sean recurrentes. No representa un diagnóstico definitivo: algunas causas requieren además registros del juego, red, controladores, SMART detallado o trazas especializadas.

Si Excel no está instalado o la creación del libro falla, el programa conserva el reporte visual y el CSV siempre que sea posible. La captura pendiente permanece además en `%LOCALAPPDATA%\AlienGamerMode\GrabacionesPendientes` para no perder la evidencia.

## Diagnóstico

Los archivos de diagnóstico se guardan en `%LOCALAPPDATA%\AlienGamerMode`:

- `discovery.json`: hardware, pantallas e inventario HWiNFO;
- `profile.json`: sensores elegidos y procesadores realmente monitorizados;
- `bridge.log`: disponibilidad del puente;
- `agent.log`: secuencia de activación y errores legibles.

Si un sensor no existe, el panel muestra `N/D` o elimina ese módulo. Los indicadores de procesador se generan sólo para lecturas reales, se compactan y conservan márgenes homogéneos.

## Desinstalación

Ejecuta `Uninstall-AlienGamerMode.ps1`. De forma predeterminada conserva la configuración y los registros. Usa `-RemoveUserConfiguration` sólo si también deseas borrar esos datos.
