# Requisitos previos — AlienGamer Mode

## Sistema compatible

- Windows 10 u 11 de 64 bits.
- PowerShell 5.1 o posterior.
- Un monitor con resolución mínima recomendada de 1280 × 720.
- Microsoft Excel sólo es necesario para generar el reporte final `.xlsx` de **Grabar evento**.

## Rainmeter

- Mínimo previsto: Rainmeter 4.5.
- Recomendado: la versión estable más reciente publicada por el proyecto.
- Descarga oficial: <https://www.rainmeter.net/>.

La skin se instala con el nombre `AlienGamerMode`, separado de `AlienGamerMode`. El instalador desactiva las skins predeterminadas de illustro al activar el panel, pero no las elimina.

## HWiNFO64

- Mínimo previsto: HWiNFO64 7.34, porque esa versión incorporó etiquetas UTF-8 en la memoria compartida.
- Recomendado y usado como referencia: HWiNFO64 8.52 estable.
- Descarga oficial: <https://www.hwinfo.com/download/>.

Configuración requerida en `HWiNFO64.INI`:

```ini
[Settings]
SensorsOnly=1
SensorsSM=1
OpenSystemSummary=0
OpenSensors=1
MinimalizeMainWnd=1
MinimalizeSensors=1
ShowWelcomeAndProgress=0
MinimalizeSensorsClose=1
```

El instalador crea una copia de seguridad del INI antes de aplicar estas opciones. HWiNFO no se redistribuye dentro del paquete: el usuario lo instala desde su fuente oficial. La edición gratuita puede limitar Shared Memory Support a 12 horas continuas; AlienGamer Mode no modifica ni evade esa política.

## Datos que confirma el usuario

El asistente obtiene automáticamente el hardware, pero solicita una selección cuando hay alternativas:

1. monitor de destino;
2. GPU a monitorizar si hay varias;
3. unidad SSD/HDD principal si hay varias;
4. accesos directos e inicio con Windows;
5. fijado manual a la barra de tareas, si se desea.

No es necesario editar la skin. La configuración personal queda en `%LOCALAPPDATA%\AlienGamerMode\AlienGamerMode.json` y se conserva durante actualizaciones.
