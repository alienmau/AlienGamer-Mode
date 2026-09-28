# AlienGamer Mode 1.6.5 — Temporizador de sesión

Esta entrega reúne las mejoras y correcciones desde la última versión pública, **1.5.9**.

## Nuevo módulo: temporizador de sesión

- Se activa de forma opcional e independiente en cada pantalla desde **Pantallas y distribución...**. Puede moverse y redimensionarse sin superponerse a los demás módulos.
- El centro abre un formulario para elegir horas, minutos, segundos y el incremento extra. **Play** se habilita después de guardar una duración; inicia o pausa la cuenta. **+** permite hasta tres incrementos extra y **X** finaliza.
- Un aro de 160 barras luminosas muestra el tiempo consumido con avance suavizado y ondas circulares. Verde hasta el 70 %, ámbar hasta el 85 % y rojo intenso después, con transición de color de unos 0,3 segundos.
- Los valores de horas, minutos y segundos giran y destellan al cambiar. **INICIAR TIMER** aparece al abrir el monitor; al llegar a cero, **GAME OVER** pulsa hasta comenzar otra sesión o finalizar. La duración y el incremento elegidos se conservan, no la sesión terminada.
- Los controles se atenúan en reposo, se iluminan al pasar el cursor y permanecen visibles durante tres segundos antes de atenuarse.

## Correcciones desde 1.5.9

- Corregida la selección de VRAM en equipos con GPU integrada y dedicada que publican nombres de sensor iguales.
- Evitadas ventanas de PowerShell auxiliares durante el arranque y la preparación del monitor.
- Reforzado el cierre coordinado desde **OFF** y **Detener monitor** de Rainmeter, HWiNFO y el puente local; el agente de bandeja permanece para reactivar el monitor.
- La instalación respalda y reinicia los estados de temporizador anteriores. Play permanece inactivo hasta definir una duración nueva.
- Pruebas de regresión para la generación de la skin, los sensores, el formulario y los estados del temporizador.

## Capturas reales

![Panel con temporizador en reposo](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.6.5/docs/images/release-1.6.5/dashboard-timer-idle.png)

![Temporizador durante una sesión](https://raw.githubusercontent.com/alienmau/AlienGamer-Mode/v1.6.5/docs/images/release-1.6.5/timer-running.png)

[Editor con temporizador](https://github.com/alienmau/AlienGamer-Mode/blob/v1.6.5/docs/images/release-1.6.5/layout-editor-timer.png) · [Formulario de duración](https://github.com/alienmau/AlienGamer-Mode/blob/v1.6.5/docs/images/release-1.6.5/timer-configuration.png)

## Instalación y comprobación

Requiere Windows 10/11 de 64 bits, Rainmeter 4.5+ y HWiNFO 7.34+ con sensores y memoria compartida habilitados. Rainmeter y HWiNFO se instalan por separado y no están incluidos. Ejecuta el instalador adjunto como administrador y selecciona Español o English.

La instalación reinicia los ajustes visuales y los estados de temporizador, guardando copias recuperables en `%LOCALAPPDATA%\AlienGamerModeLegacyBackup`. Las grabaciones y los reportes existentes se conservan.

Pruebas automáticas y compilación: aprobadas. Las capturas corresponden a la validación visual del usuario. El consumo con el temporizador durante una partida no se ha medido todavía; las cifras generales del README son orientativas de una configuración anterior.

Archivo: `AlienGamerMode-Setup-1.6.5.exe`
SHA-256: `5AB5E7DE7FCEB572F7455EB6A62DA4F69FA9430905E7A4B359BABBBE1D8E1BA1`

## English summary

Version 1.6.5 adds an optional per-display session timer with a configurable duration, up to three extra-time increments, a smooth 160-bar progress ring, rolling digits, and a pulsing **GAME OVER** alert. The ring changes from green (0–70%) to amber (70–85%) to red (85–100%) with a short color transition. This release also fixes VRAM mapping on mixed integrated/discrete GPU systems, removes stray PowerShell windows, and strengthens coordinated shutdown through **OFF**. Setup backs up and resets old timer sessions while preserving recordings and reports. Rainmeter and HWiNFO are separate requirements.
