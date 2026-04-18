# Changelog

All notable changes to StatsBar are documented here.

---

## [Unreleased]

### Added

- **Proactive system notifications** — StatsBar now sends macOS notifications when metrics exceed danger thresholds, helping you catch runaway processes before they hang the system.
  - **CPU usage** alert at ≥ 90%
  - **GPU usage** alert at ≥ 90%
  - **Memory usage** alert at ≥ 90%
  - **Swap usage** alert at ≥ 80% (lower threshold since swap pressure precedes RAM exhaustion)
  - **Total power draw** (CPU + GPU + ANE) alert at ≥ 30W, indicating likely thermal throttling
- **Cooldown per alert type** — each alert category has a 60-second cooldown so repeated spikes don't flood Notification Center. The cooldown resets when the metric drops back below its threshold.
- **Notification permission request** — the app now requests notification authorization on first launch via `UNUserNotificationCenter`.
- New file: `Service/NotificationManager.swift` containing `NotificationManager` (singleton) and `AlertThresholds` (configurable thresholds struct).

### Changed

- `StatsBarApp.swift` — added `UserNotifications` import and permission request in `applicationDidFinishLaunching`.
- `MenuView.swift` — `updateSamples` now calls `NotificationManager.shared.evaluate(metrics:)` after every sample cycle.

---

## [1.0.0] — Initial Release

### Features

- CPU usage monitoring (E-Cores and P-Cores separately)
- GPU usage monitoring
- Memory and swap usage
- Network upload/download throughput
- Disk read/write throughput
- Power draw (CPU, GPU, ANE, system total)
- Menu bar live stats widget with per-core bar graphs
- Historical usage charts in the dropdown panel
- Launch at login support
