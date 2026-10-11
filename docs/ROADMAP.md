# Próximas mejoras

**Entrega 1.8.0 (2026-10-10):** HTTPS local, guía CA/no Wi-Fi, pantalla encendida compatible, temporizador único autorizado y fix de accesos PowerShell se incluyen en esta versión. El usuario confirmó el recorrido en su teléfono. Las notas de diagnóstico siguientes conservan el historial de desarrollo; no significan que esas funciones sigan pendientes. Próximos: validación física en iOS/tablets, más equipos/topologías y visualización de ventiladores sólo cuando existan RPM reales.

## Revisión instalada — 2026-10-10

- El usuario confirma que aún aparece una consola al arrancar. Se inspeccionaron los accesos reales: escritorio y menú Inicio apuntan a `wscript.exe` con el lanzador gráfico; el acceso fijado en la barra de tareas todavía apuntaba directamente a `powershell.exe -File AlienGamerModeAgent.ps1 -Activate`. Esta ruta evita el host sin consola.
- Se migró ese acceso local al lanzador actual, conservando una copia `.before-hidden-launch.bak`. `src/Repair-AlienGamerShortcuts.ps1` migra únicamente invocaciones al agente de la instalación indicada; no modifica desinstaladores ni otros accesos. El instalador ejecuta esa reparación para evitar que sobrevivan enlaces antiguos tras actualizar. No se publicó ni reemplazó el instalador v1.7.0.
- `Test-ShortcutMigration.ps1` pasa en Windows PowerShell 5.1: activación e inicio migrados, copia de seguridad, exclusión de enlaces ajenos e idempotencia. `Test-HiddenProcesses.ps1` vuelve a pasar. El usuario confirma que la ventana de PowerShell ya no aparece tras la reparación. Incluir en la próxima versión y sus notas ES/EN el fix de accesos antiguos fijados en la barra de tareas; conservar la migración del instalador y las pruebas de regresión.
- Inspección de HWiNFO en vivo: 673 lecturas, ninguna con unidad RPM ni etiqueta de ventilador. Esto sólo describe el inventario expuesto en esta sesión/equipo; no demuestra que el hardware carezca de ventiladores. El módulo deberá aceptar sensores ausentes y no inventar velocidades.
- El usuario aceptó HTTPS local y su asistente guiado con UI/UX Pro Max. Ya están implementados en desarrollo el asistente ES/EN, preparación HTTP con certificado público/huella, TLS en el mismo puerto LAN, cambio voluntario de protocolo y guía de instalación/retirada. Pruebas locales de certificados y puente TLS pasan; no se ha instalado confianza en ningún teléfono ni publicado un instalador nuevo. Pendiente: prueba física de confianza y Wake Lock en Android/iOS. Detalles y límites en `MOBILE-LAN.md`.
- Actualización local: `installer/Update-MobileHttps.ps1` cambia sólo cuatro archivos, respalda los anteriores y revierte copias parciales; no modifica preferencias ni certificados. La primera ejecución sin elevación fue rechazada y revertida. Se solicitó elevación mediante el host gráfico existente; mientras no exista confirmación de resultado, no afirmar que la instalación ya contiene HTTPS. Es necesario aceptar el aviso de Windows y reiniciar AlienGamer desde su menú antes de probar el asistente.

### Texto base para la próxima entrega / Next release notes

2026-10-10 — Corrección del asistente HTTPS tras prueba del usuario: controles del asistente aislados de los del editor, actualización QR de la ventana padre suspendida durante el diálogo modal y ruta de QRCoder conservada en callbacks. Evita el cruce de variables que producía errores repetidos de propiedad `Text`. El cierre no cambia el protocolo; Volver a HTTP sigue siendo una acción explícita. Botón HTTPS naranja con explicación de requisito y pasos, sin tener que desactivar/reactivar el servicio. Prueba de regresión con ambos diálogos anidados: QR visible, confirmación manual, activación, cierre y recuperación del QR padre. Pendiente verificar nuevamente en el celular real.

EN: Fixed nested HTTPS setup dialogs interfering with the mobile QR refresh and generating repeated control-property errors. Isolated wizard controls, paused parent refresh, and preserved the QR assembly path. Added a prominent HTTPS action with prerequisite and next-step guidance. Verified nested-dialog QR rendering, explicit confirmation, activation, close and parent refresh. Physical-phone trust verification remains pending.

Corrección instalada localmente con resultado confirmado y hashes coincidentes: respaldo `C:\ProgramData\AlienGamerMode\UIBackups\https-20261010-141434-678`. Preferencias intactas y ninguna confianza instalada. La ventana del editor que estaba abierta antes de la actualización debe cerrarse y reabrirse; sigue ejecutando el código previo. No se publicó esta actualización.

Actualización instalada confirmada el 2026-10-10 tras aceptar el aviso de Windows: cuatro archivos HTTPS actualizados, preferencias sin cambios y ninguna confianza instalada. Respaldo: `C:\ProgramData\AlienGamerMode\UIBackups\https-20261010-140421-693`. Falta reiniciar el agente y probar el asistente con el celular.

**ES:** Corrección del arranque que dejaba una consola PowerShell abierta desde accesos antiguos fijados en la barra de tareas. El instalador ahora migra esos accesos al lanzador gráfico sin consola, conservando respaldo. Nueva conexión HTTPS LAN opcional con asistente paso a paso, certificado propio de cada instalación, huella verificable y configuración voluntaria de confianza en el teléfono. Mantiene HTTP como alternativa. La función de pantalla encendida depende del navegador y sus permisos; no está garantizada en todos los equipos.

**EN:** Fixed startup leaving a PowerShell console open when using legacy taskbar shortcuts. The installer now migrates those shortcuts to the console-free graphical launcher while preserving a backup. Added optional local-network HTTPS with a step-by-step wizard, an installation-specific certificate, a verifiable fingerprint and voluntary phone trust setup. HTTP remains available. Keeping the screen awake depends on browser support and permission; it is not guaranteed on every device.

Este texto es preparación, no una publicación ni confirmación de compatibilidad física. / These notes are a draft, not a publication or confirmation of physical-device compatibility.

## Consola visible al iniciar — corrección confirmada por el usuario

La corrección anterior reemplazó un arranque minimizado del editor y rutas que sólo pedían ocultar la consola por un host gráfico y `UseShellExecute=false / CreateNoWindow=true`, conservando diagnósticos y procesos independientes. Ya existe en la instalación; no basta si un acceso antiguo abre PowerShell directamente. Véase la revisión instalada anterior.

- Tras aprobar el diseño e instalar: comprobar el inicio real; si persiste una ventana, identificar ejecutable, proceso padre y línea de lanzamiento, no deducir que es prescindible sólo porque puede cerrarse.
- Revisar por separado acceso directo, lanzador, agente, servicio móvil y sensores; localizar el responsable antes de cambiar su arranque.
- Mantener en funcionamiento todos los procesos necesarios sin ventana de consola. Validar lanzamiento, cierre y continuidad de datos, con servicio móvil activo/inactivo.
- La confirmación actual corresponde a la reparación del acceso fijado, no sólo a la corrección anterior del host de HWiNFO. Conservar pruebas de arranque para las demás rutas.

## Módulo de ventiladores — pendiente, después de Estudio

Petición del usuario: representar ventiladores con un diseño minimalista, armonioso y elegante. Giro animado proporcional a las RPM reales, acompañado de un efecto sutil de aire/vapor atravesando el ventilador.

Antes de implementarlo:

1. Comprobar si HWiNFO expone sensores de velocidad en RPM para cada equipo, identificar nombre, unidad y origen, y mantener su lectura en tiempo real. No asumir que todos los portátiles o GPU exponen ventiladores.
2. Diferenciar velocidad medida, ventilador detenido, sensor ausente y dato caducado; no sustituir ausencia por 0 RPM.
3. Mostrar valor y unidad junto a una animación suavizada y limitada, con opción de movimiento reducido. El efecto de aire será representativo de RPM, no una medición de caudal o temperatura.
4. Reutilizar visibilidad, ubicación y tamaños del editor, y adaptar posteriormente la tarjeta móvil.
5. No controlar ventiladores ni cambiar curvas de refrigeración: primera etapa de sólo lectura.

La factibilidad y los sensores disponibles siguen pendientes de validación. Esta nota no afirma que el módulo esté implementado.
