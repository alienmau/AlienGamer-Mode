# Instalación y prueba manual

## Identidad de la edición oficial

AlienGamer Mode usa:

- skin `AlienGamerMode`;
- puerto local `27843`;
- datos en `%LOCALAPPDATA%\AlienGamerMode`;
- acceso `Activar AlienGamer Mode`.

El instalador sustituye las ediciones anteriores, migra la selección de monitor, GPU y unidad cuando existe, y conserva un respaldo en `%LOCALAPPDATA%\AlienGamerModeLegacyBackup`.

## Instalación

1. Instala Rainmeter y HWiNFO64 desde sus sitios oficiales.
2. Cierra HWiNFO para que su archivo de configuración no sea reescrito mientras se prepara.
3. Ejecuta `installer\Install-AlienGamerMode.ps1`.
4. Selecciona monitor, GPU y unidad principal.
5. Elige Escritorio, menú Inicio e inicio con Windows.
6. Pulsa **Instalar y configurar**.
7. Espera la ventana de preparación. El primer arranque descubre sensores, genera el perfil y adapta el diseño.

El instalador registra `AlienGamerMode-HWiNFO`, una tarea que inicia HWiNFO con privilegios suficientes para publicar Shared Memory sin solicitar UAC en cada arranque. Las tareas obsoletas se retiran durante la migración.

## Icono de bandeja

Mientras el agente está abierto, el logotipo aparece en los iconos ocultos de Windows. Su menú ofrece:

- Activar monitor / Detener monitor, según el estado real;
- Grabar evento / Finalizar grabación / Finalizando reporte, según la captura;
- Configuración avanzada;
- Abrir registros y reportes;
- Cerrar AlienGamer Mode.

**Detener monitor** desactiva la skin y cierra el puente, pero conserva el agente en la bandeja para poder activarlo nuevamente. **Cerrar AlienGamer Mode** también retira el agente. HWiNFO y Rainmeter sólo se cierran automáticamente cuando fueron iniciados por esta edición. Si existe una grabación, se finaliza antes de detener el monitor.

## Diagnóstico

Los archivos de diagnóstico se guardan en `%LOCALAPPDATA%\AlienGamerMode`:

- `discovery.json`: hardware, pantallas e inventario HWiNFO;
- `profile.json`: sensores elegidos y procesadores realmente monitorizados;
- `bridge.log`: disponibilidad del puente;
- `agent.log`: secuencia de activación y errores legibles.

Si un sensor no existe, el panel muestra `N/D` o elimina ese módulo. Los indicadores de procesador se generan sólo para lecturas reales, se compactan y conservan márgenes homogéneos.

## Desinstalación

Ejecuta `Uninstall-AlienGamerMode.ps1`. De forma predeterminada conserva la configuración y los registros. Usa `-RemoveUserConfiguration` sólo si también deseas borrar esos datos.
