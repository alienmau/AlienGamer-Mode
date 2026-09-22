# AlienGamer Mode 1.5.7 — candidato local de prueba

Esta compilación introduce instalaciones visualmente limpias durante la estabilización del editor multidisplay. Todavía no se ha publicado.

## Instalación limpia

- Cada instalación reemplaza los ajustes visuales activos por la configuración oficial.
- La pantalla elegida inicia habilitada con **Completo horizontal** y todos los módulos visibles.
- El editor se abre al finalizar para conservar ese diseño o personalizarlo.
- La configuración anterior se respalda en `%LOCALAPPDATA%\AlienGamerModeLegacyBackup`.
- Las grabaciones, CSV, Excel, reportes HTML e historial de comparaciones se conservan.

## Aplicación en caliente

- Valida que la reconstrucción multidisplay termine correctamente y produzca un manifiesto nuevo.
- Registra las etapas construir, desactivar, instalar y activar en `%LOCALAPPDATA%\AlienGamerMode\agent-diagnostic.log`.
- Las notificaciones de bandeja son opcionales y ya no pueden invalidar un guardado correcto.
- Un posible fallo informa la etapa exacta para evitar diagnósticos ambiguos.

## Estado de publicación

- GitHub: no publicado.
- Foros: no publicado.
- Instalador local: `build/installer/AlienGamerMode-Setup-1.5.7.exe`.
- Tamaño: 5.15 MB.
- SHA-256: `65B20E9A36A74A98532D5E556FBF690C3A78155E45476D04E6EB99A6874A65D2`.
- Pruebas automatizadas: superadas.
