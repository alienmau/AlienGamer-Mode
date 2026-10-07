# Arranque de sensores sin consola — candidato 1.7.0

El instalador y el reparador registran `AlienGamerMode-HWiNFO` con el usuario interactivo y privilegios máximos. La acción ahora ejecuta `assets/AlienGamerSensorHost.exe`, no HWiNFO directamente ni un PowerShell residente.

El host es un ejecutable .NET Framework x64 de subsistema GUI: no crea consola ni pestaña de Windows Terminal. Verifica la elevación, inicia la ruta instalada de HWiNFO con ShellExecute y vigila únicamente el proceso que él mismo inició. Si HWiNFO ya estaba abierto por otra aplicación, no toma propiedad de ese proceso.

El agente solicita el cierre mediante `%LOCALAPPDATA%\AlienGamerMode\stop-hwinfo.signal`. El host elevado termina su proceso hijo y sale. Los diagnósticos quedan en `hwinfo-task.log` con el prefijo `NativeHost`.

## Compilación y comprobaciones

- `installer/Build-SensorHost.ps1` compila el código de `src/native/AlienGamerSensorHost.cs` con el compilador de .NET Framework de Windows.
- `installer/Build-Installer.ps1` reconstruye el host antes de empaquetarlo, evitando incluir un binario antiguo.
- `tests/Test-AlienGamerMode.ps1` comprueba la construcción real de la tarea en memoria y verifica que el ejecutable sea GUI, no consola.
- `tests/Test-SensorHostLive.ps1 -ResultPath <ruta>` requiere elevación. Utiliza la definición real del instalador, una tarea temporal sin disparadores, verifica arranque, memoria compartida y cierre cooperativo. Elimina la tarea temporal al terminar. Se niega a interrumpir HWiNFO si ya estaba abierto antes de la prueba.

Esta corrección sustituye la acción directa que devolvía `0x800702E4` en el equipo de prueba. El antiguo error de ruta nula se corrige por separado usando `hwinfoPath` y verificando la existencia de ambos ejecutables antes del registro.
