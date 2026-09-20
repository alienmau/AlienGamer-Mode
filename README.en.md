# AlienGamer Mode

[Español](README.md) · **English**

**Adaptive Windows hardware and sensor monitoring for gamers.**

![AlienGamer Mode dashboard](docs/images/AlienGamerMode-social-preview.png)

[![Latest release](https://img.shields.io/github/v/release/alienmau/AlienGamer-Mode?style=for-the-badge&color=ff7a00)](https://github.com/alienmau/AlienGamer-Mode/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/alienmau/AlienGamer-Mode/total?style=for-the-badge&color=22d3ee)](https://github.com/alienmau/AlienGamer-Mode/releases)
[![MIT License](https://img.shields.io/github/license/alienmau/AlienGamer-Mode?style=for-the-badge&color=84cc16)](LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-2563eb?style=for-the-badge)](#requirements)

**[Download the latest release](https://github.com/alienmau/AlienGamer-Mode/releases/latest)** · **[Report an issue](https://github.com/alienmau/AlienGamer-Mode/issues/new/choose)**

AlienGamer Mode is a Rainmeter and HWiNFO dashboard that detects the available hardware, adapts its layout to the selected display and avoids presenting missing sensors as real zero values.

Version 1.4.0 automatically creates a visual HTML report with charts whenever a recording ends, alongside the Excel workbook and raw CSV. It also includes the fully hidden startup and reliable OFF fallback introduced in 1.3.5.

## Highlights

- RAM, VRAM, CPU/GPU usage and temperatures.
- Dynamic per-core load with automatic removal and reordering of unavailable sensors.
- FPS and frame time with clear visual classifications.
- Thermal and power-limit indicators when HWiNFO provides them.
- Matrix-style clock, custom or thermal-dynamic ambient fireflies, and dark glass panels.
- OLED protection through subtle periodic pixel shifting.
- Manual event recording with a technical Excel report.
- Persistent visibility controls for the processor panel, FPS/alerts panel and clock.
- Display, GPU and primary-drive selection during installation.
- Spanish and English UI, selectable during installation or from the tray icon.

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
3. Download and run `AlienGamerMode-Setup-1.4.0.exe` as administrator.
4. Choose **English** or **Español**, then select the target display, GPU and primary drive.
5. Finish installation; the dashboard starts automatically and remains available from the tray icon.

## Changing the language

Right-click the AlienGamer Mode tray icon and choose **Language → English** or **Idioma → Español**. The selection is saved and the active Rainmeter skin is regenerated and refreshed without restarting HWiNFO or the sensor bridge. If the monitor is stopped, the new language is applied the next time it starts.

## Thermal dynamic background

Open **Background** from the tray icon and choose **Off**, **Custom**, or **Thermal dynamic**. Custom mode keeps the user-selected color. Thermal mode compares valid CPU, maximum-core and GPU temperatures against component-specific thresholds; the most demanding valid state controls the firefly color. A reported thermal-throttling flag forces the critical red state.

Firefly density blends recent frame-time fluidity/stability with CPU/GPU activity. When GPU saturation or degraded frame time is detected, thermal mode gradually reduces particles and movement to yield resources to the game. Custom firefly controls are available only in **Custom** mode; **Thermal dynamic** uses separate conservative automatic parameters. Missing sensors are ignored rather than interpreted as real zero values.

Use **Configure hardware and display...** from the tray to change the target display, GPU or primary storage without reinstalling. Displays are saved by physical identity, so the selection survives Windows renaming `DISPLAY1` to another number.

## Recording a performance event

While the monitor is active it keeps a local rolling buffer covering the previous 60 seconds. When you notice stutter, freezes or another suspicious behavior, press **Record event**. Choose **Mark incident now** in the tray menu whenever the symptom appears; right-clicking the skin's record button also creates a marker.

Finishing a recording creates three companion files: a responsive standalone HTML report, an Excel workbook and the raw CSV. The visual report opens in any modern browser without an Internet connection and includes an executive summary, a 0–100 stability score, separate correctly scaled FPS and frame-time charts, temperatures, utilization and marked incidents. The workbook retains raw samples, incident windows, comparison with the previous local session and a privacy sheet. The CSV remains available for independent or AI-assisted analysis.

Excel is optional. If it is not installed or workbook creation fails, AlienGamer Mode still preserves the visual report and raw CSV whenever possible.

The resulting report can help correlate the symptom with overheating, resource saturation, throttling or frame-time instability. Its interpretation is preliminary: it does not prove a root cause or replace game logs, detailed SMART diagnostics, network analysis or specialized traces.

## Compact FPS mode

Choose **Visible modules → Compact FPS mode** to hide the full dashboard and center only the FPS, frame-time and alert panel on the selected screen. The setting persists without disabling sensor capture.

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
