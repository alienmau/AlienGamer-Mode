# AlienGamer Mode

[Español](README.md) · **English**

**Adaptive Windows hardware and sensor monitoring for gamers.**

Version **1.7.0** adds a [QR-based local mobile dashboard](docs/MOBILE-LAN.md) and refreshed [Display layout](docs/DESKTOP-STUDIO.md): rounded display cards above a centered preview, vertical options below, and a unified dark theme with an orange accent. [Detailed bilingual notes and screenshots](docs/RELEASE-1.7.0.md). GUI process launchers prevent console allocation while retaining dialogs and diagnostics; final installed-startup confirmation remains open. [Roadmap](docs/ROADMAP.md) includes a fan module, pending real RPM sensor availability.

![AlienGamer Mode 1.6.5 with session timer](docs/images/release-1.6.5/dashboard-timer-idle.png)

[![Latest release](https://img.shields.io/github/v/release/alienmau/AlienGamer-Mode?style=for-the-badge&color=ff7a00)](https://github.com/alienmau/AlienGamer-Mode/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/alienmau/AlienGamer-Mode/total?style=for-the-badge&color=22d3ee)](https://github.com/alienmau/AlienGamer-Mode/releases)
[![MIT License](https://img.shields.io/github/license/alienmau/AlienGamer-Mode?style=for-the-badge&color=84cc16)](LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-2563eb?style=for-the-badge)](#requirements)

**[Download the latest release](https://github.com/alienmau/AlienGamer-Mode/releases/latest)** · **[Report an issue](https://github.com/alienmau/AlienGamer-Mode/issues/new/choose)**

AlienGamer Mode is a Rainmeter and HWiNFO dashboard that detects the available hardware, adapts its layout to the selected display and avoids presenting missing sensors as real zero values.

Version 1.6.5 adds an optional per-display session timer. Configure it from the module itself, keep your chosen duration and extra-time step, and follow an animated countdown ring through to a **GAME OVER** alert. This update also fixes VRAM selection on systems with both integrated and discrete GPUs, removes auxiliary PowerShell windows, and strengthens coordinated shutdown through **OFF**. The multi-display editor continues to support independent module visibility, placement, and size per screen.

## Highlights

- RAM, VRAM, CPU/GPU usage and temperatures.
- Dynamic per-core load with automatic removal and reordering of unavailable sensors.
- FPS and frame time with clear visual classifications.
- Thermal and power-limit indicators when HWiNFO provides them.
- Matrix-style clock, custom or thermal-dynamic ambient fireflies, and dark glass panels.
- Optional per-display session timer with configurable duration and extra-time increments, animated progress ring, and an end-of-time alert.
- OLED protection through subtle periodic pixel shifting.
- Manual event recording with a technical Excel report.
- Persistent per-display visibility, position and size for optional modules.
- Display, GPU and primary-drive selection during installation.
- Spanish and English UI, selectable during installation or from the tray icon.
- Multiple simultaneous local-display views with independent persistent layouts.
- Drag-and-resize editing for RAM, VRAM, usage, temperatures, FPS, processors, clock, timer and controls; the header remains fixed and mandatory.

![AlienGamer Mode running](docs/images/AlienGamerMode-dashboard.png)

## Requirements

- 64-bit Windows 10 or Windows 11.
- 4 GB RAM minimum; 8 GB recommended, or 16 GB when gaming on the same PC.
- Dual-core x64 processor or better.
- Approximately 100 MB free storage, excluding saved reports.
- [Rainmeter 4.5 or later](https://www.rainmeter.net/).
- [HWiNFO 7.34 or later](https://www.hwinfo.com/download/) with sensors and Shared Memory Support enabled.
- Microsoft Excel is optional and only needed to open `.xlsx` reports directly.

Rainmeter and HWiNFO are third-party products and are not bundled with this repository.

### Approximate resource usage

On the development system, with 24 logical processors, all sensors, 48 fireflies and 10 FPS visual animation, the complete stack averaged approximately **457 MB RAM** and **5.4% total CPU**. Actual usage varies by hardware, sensor count, other Rainmeter skins and visual settings.

## Installation

1. Install Rainmeter and HWiNFO from their official sites.
2. Enable sensors and **Shared Memory Support** in HWiNFO.
3. Download and run `AlienGamerMode-Setup-1.7.0.exe` as administrator.
4. Choose **English** or **Español**, then select the target display, GPU and primary drive.
5. Finish installation; the dashboard starts automatically and remains available from the tray icon.

## Displays and layout

Open the tray menu and choose **Displays and layout...**. The editor represents each connected screen at its real aspect ratio and can enable several displays, drag and resize each optional module, hide blocks, apply horizontal or vertical presets, and select a separate background mode for every view. Manual backgrounds expose particle count, speed, size and color controls; thermal mode manages those values automatically.

Presets update the preview immediately, while the live dashboard changes only after **Save and apply**. Modules remain inside screen bounds, keep a minimum separation and cannot overlap. The mandatory header cannot be dragged and stays at the upper-left safety margin, except in **Essential portrait**, where it is centered at the top. Saving rebuilds only the Rainmeter views; HWiNFO, the local bridge and event recording remain shared.

Layouts are stored under `displayViews` in `%LOCALAPPDATA%\AlienGamerMode\AlienGamerMode.json` and survive restarts. The editor opens after setup with the full traditional layout; the optional timer starts hidden. Each installation resets visual settings with recoverable backups, preserving recordings/reports. Version 1.7.0 adds a read-only mobile companion tested on an actual Chrome phone.

### Multiple displays and visual layout

One AlienGamer Mode installation can activate a different view on every connected display:

- Each display can be enabled or disabled without stopping the others.
- Clock, controls, RAM, VRAM, CPU/GPU usage, temperatures, FPS/alerts, and processor modules are selected independently per display.
- Visible modules can be dragged and resized inside a preview that preserves the real display resolution and aspect ratio.
- The editor prevents overlaps, unsafe spacing, and out-of-bounds placement. The identifying header remains fixed and visible.
- Full horizontal, essential horizontal, essential vertical, performance-only, and temperatures-only presets can be previewed before applying.
- Each display has its own disabled, custom, or thermal dynamic background.
- Layout choices persist across restarts.
- Visual-only changes reuse the validated sensor profile, show an `Applying changes…` notice on affected displays, and avoid restarting HWiNFO or the data bridge.

To keep the tray menu concise, the former global **Background** and **Visible modules** menus now live under **Displays and layout...**, where they can be configured correctly for each display. The main menu keeps global actions such as starting/stopping the monitor, recording or marking incidents, language selection, hardware/display selection, logs, and closing the app.

![Displays and layout editor](docs/images/AlienGamerMode-layout-editor.png)

![Customized AlienGamer Mode 1.5.8 view](docs/images/AlienGamerMode-dashboard-1.5.8.png)

## Session timer

Enable the timer in **Displays and layout...**, then drag and resize it for that display. Click its center to set hours, minutes, seconds and the extra-time step. Play stays disabled until a duration is saved; afterwards it starts or pauses the countdown. **+** provides up to three extra-time increments, and **X** ends the session.

The progress ring advances smoothly, with 160 moving light bars. It stays green through 70% of elapsed time, turns amber through 85%, then bright red, with an approximately 0.3-second color transition. Changing digits roll and flash. At zero, **GAME OVER** stays fixed. An unconfigured timer shows zeroes; reopening restores the saved duration ready to start, not a completed session.

![Session timer running](docs/images/release-1.6.5/timer-running.png)

![Timer settings](docs/images/release-1.6.5/timer-configuration.png)

![Timer in the layout editor](docs/images/release-1.6.5/layout-editor-timer.png)

### Local mobile dashboard — 1.7.0

Open **Displays and layout → Mobile display (phone / tablet)** and enable **Enable web monitor on my local network**: the service starts and its QR appears automatically. Choose modules and click **Apply modules** to save selection changes. Scan the QR on a device connected to the same router; the laptop may use Ethernet while the phone uses Wi-Fi. Cards adapt to portrait and landscape. **Fullscreen** and **Exit fullscreen** affect only the phone browser, never the laptop monitor or its background services.

The LAN service is off by default. It binds to a private address on port 27844, does not use cloud services, and requires the QR's secret link. **New QR** automatically revokes the previous link; disabling access stops the LAN listener. The installer creates a firewall rule scoped to this port and the local subnet. Anyone on that subnet with the QR can see the sensor metrics. Fullscreen requires a tap and depends on browser support; some mobile browsers may keep their navigation bar.

The mobile view includes a matrix clock, individual RAM/VRAM/CPU/GPU rings, grouped temperatures, and decorative fireflies. **Edit (Editar)** supports ordering, visibility, and three sizes: **Minimum (Mínimo)** uses one column unit, **Normal** uses the module's base width, and **Extended (Extendido)** fills the entire row. A responsive masonry layout packs natural-height cards without row-height gaps or fixed heights, preserves column units across rotation, and treats Extended cards as full-width separators. FPS and frame time form one module; both that module and alerts use 2 units at Normal size. Cards have a translucent glass effect and centered titles. Edit also lets you choose the firefly color. Preferences are stored on each device. **Expand (Expandir)** and **Exit (Salir)** control fullscreen; Chrome's entry notification cannot be modified by the page.

**Edit → Keep screen awake (Mantener pantalla encendida)** requests native screen wake lock only in a supported secure context. The current HTTP LAN link disables the option with an explanation; no manual certificates or security changes are required. “Active” appears only after an actual grant, and denial/release is reflected in the control. Manual locking remains possible. The video workaround was removed; local HTTPS is not implemented and universal device support is not promised. See [Mobile dashboard documentation](docs/MOBILE-LAN.md).

The user confirmed LAN access from Chrome over Wi-Fi and supplied portrait, landscape and mobile-editor screenshots of the revised design. Automated tests cover the server, QR, eight resolutions, saved editing, dragging, and rotation. Physical tablet/iOS coverage and final installed-console confirmation remain open; no universal device or wake-lock support is claimed.

## Changing the language

Right-click the AlienGamer Mode tray icon and choose **Language → English** or **Idioma → Español**. The selection is saved and the active Rainmeter skin is regenerated and refreshed without restarting HWiNFO or the sensor bridge. If the monitor is stopped, the new language is applied the next time it starts.

## Thermal dynamic background

Open **Displays and layout...** to choose **Off**, **Custom**, or **Thermal dynamic** independently for every monitor. Custom mode keeps that display's selected color and particle settings. Thermal mode compares valid CPU, maximum-core and GPU temperatures against component-specific thresholds; the most demanding valid state controls the firefly color. A reported thermal-throttling flag forces the critical red state. The former global **Background** tray menu was removed so one action cannot overwrite every display.

Firefly density blends recent frame-time fluidity/stability with CPU/GPU activity. When GPU saturation or degraded frame time is detected, thermal mode gradually reduces particles and movement to yield resources to the game. Custom firefly controls are available only in **Custom** mode; **Thermal dynamic** uses separate conservative automatic parameters. Missing sensors are ignored rather than interpreted as real zero values.

Use **Configure hardware and display...** from the tray to change the target display, GPU or primary storage without reinstalling. Displays are saved by physical identity, so the selection survives Windows renaming `DISPLAY1` to another number.

## Recording a performance event

While the monitor is active it keeps a local rolling buffer covering the previous 60 seconds. When you notice stutter, freezes or another suspicious behavior, press **Record event**. Choose **Mark incident now** in the tray menu whenever the symptom appears; right-clicking the skin's record button also creates a marker.

Finishing a recording creates three companion files: a responsive standalone HTML report, an Excel workbook and the raw CSV. The visual report opens in any modern browser without an Internet connection and includes an executive summary, a 0–100 stability score, separate correctly scaled FPS and frame-time charts, temperatures, utilization and marked incidents. The workbook retains raw samples, incident windows, comparison with the previous local session and a privacy sheet. The CSV remains available for independent or AI-assisted analysis.

Excel is optional. If it is not installed or workbook creation fails, AlienGamer Mode still preserves the visual report and raw CSV whenever possible.

The resulting report can help correlate the symptom with overheating, resource saturation, throttling or frame-time instability. Its interpretation is preliminary: it does not prove a root cause or replace game logs, detailed SMART diagnostics, network analysis or specialized traces.

## Performance view

In **Displays and layout...**, choose the **Performance only** preset to center the FPS, frame-time and alert panel. Before saving, it can be moved, resized or combined with other modules. The setting persists without disabling sensor capture.

## Privacy

AlienGamer Mode runs locally and sends no telemetry. Reports are created only when the user starts an event recording and may contain process names and hardware details; review them before sharing.

## Build and test

Install Inno Setup 6, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-AlienGamerMode.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\installer\Build-Installer.ps1
```

The installer is generated in `build/installer/`.

## License

Original project code is released under the [MIT License](LICENSE). Third-party names and components retain their respective licenses.

Created by **Alienmau**.
