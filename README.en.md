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

## Highlights

- RAM, VRAM, CPU/GPU usage and temperatures.
- Dynamic per-core load with automatic removal and reordering of unavailable sensors.
- FPS and frame time with clear visual classifications.
- Thermal and power-limit indicators when HWiNFO provides them.
- Matrix-style clock, configurable ambient fireflies and dark glass panels.
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
3. Download and run `AlienGamerMode-Setup-1.2.0.exe` as administrator.
4. Choose **English** or **Español**, then select the target display, GPU and primary drive.
5. Finish installation; the dashboard starts automatically and remains available from the tray icon.

## Changing the language

Right-click the AlienGamer Mode tray icon and choose **Language → English** or **Idioma → Español**. The selection is saved and the active Rainmeter skin is regenerated and refreshed without restarting HWiNFO or the sensor bridge. If the monitor is stopped, the new language is applied the next time it starts.

## Recording a performance event

When you notice stutter, freezes, low fluidity or another suspicious behavior, press **Record event**. Press **Stop recording** when the incident ends. AlienGamer Mode captures the available FPS, frame time, temperatures, CPU/GPU load, RAM, VRAM, storage temperature, per-core load and thermal/power-limit flags for that interval.

The resulting report can help correlate the symptom with overheating, resource saturation, throttling or frame-time instability. It is an aid for preliminary diagnosis and does not replace game logs, detailed SMART diagnostics, network analysis or specialized traces.

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
