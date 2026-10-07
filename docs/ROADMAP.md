# Próximas mejoras

## Consola visible al iniciar — corrección adelantada, pendiente de prueba instalada

El usuario autorizó adelantar este trabajo mientras duerme. No había agente/bridge/terminal de AlienGamer activo durante la inspección, por lo que no se pudo atribuir la ventana histórica a un PID concreto. Se encontró un arranque explícitamente minimizado para el editor y rutas que sólo pedían ocultar la consola. Se reemplazaron por un host gráfico y `UseShellExecute=false / CreateNoWindow=true`, conservando diagnósticos y procesos independientes. Las pruebas aisladas pasan; no se ha cambiado la instalación.

- Tras aprobar el diseño e instalar: comprobar el inicio real; si persiste una ventana, identificar ejecutable, proceso padre y línea de lanzamiento, no deducir que es prescindible sólo porque puede cerrarse.
- Revisar por separado acceso directo, lanzador, agente, servicio móvil y sensores; localizar el responsable antes de cambiar su arranque.
- Mantener en funcionamiento todos los procesos necesarios sin ventana de consola. Validar lanzamiento, cierre y continuidad de datos, con servicio móvil activo/inactivo.
- No dar por resuelto este bug por la corrección anterior del host de HWiNFO: el usuario confirma que todavía ocurre.

## Módulo de ventiladores — pendiente, después de Estudio

Petición del usuario: representar ventiladores con un diseño minimalista, armonioso y elegante. Giro animado proporcional a las RPM reales, acompañado de un efecto sutil de aire/vapor atravesando el ventilador.

Antes de implementarlo:

1. Comprobar si HWiNFO expone sensores de velocidad en RPM para cada equipo, identificar nombre, unidad y origen, y mantener su lectura en tiempo real. No asumir que todos los portátiles o GPU exponen ventiladores.
2. Diferenciar velocidad medida, ventilador detenido, sensor ausente y dato caducado; no sustituir ausencia por 0 RPM.
3. Mostrar valor y unidad junto a una animación suavizada y limitada, con opción de movimiento reducido. El efecto de aire será representativo de RPM, no una medición de caudal o temperatura.
4. Reutilizar visibilidad, ubicación y tamaños del editor, y adaptar posteriormente la tarjeta móvil.
5. No controlar ventiladores ni cambiar curvas de refrigeración: primera etapa de sólo lectura.

La factibilidad y los sensores disponibles siguen pendientes de validación. Esta nota no afirma que el módulo esté implementado.
