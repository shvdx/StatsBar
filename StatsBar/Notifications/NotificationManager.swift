//
//  NotificationManager.swift
//  StatsBar
//

import Foundation
import UserNotifications

struct AlertThresholds {
    var cpuUsage: Double = 90.0  // %
    var gpuUsage: Double = 90.0  // %
    var memUsage: Double = 90.0  // %
    var swapUsage: Double = 80.0  // %
    var totalPower: Float32 = 30.0  // Watts (CPU + GPU + ANE)
    var cooldown: TimeInterval = 60.0  // seconds between repeat alerts for the same metric
}

class NotificationManager {
    static let shared = NotificationManager()
    static let enabledKey = "notificationsEnabled"

    var thresholds = AlertThresholds()

    var isEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool
                ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue {
                lastNotified.removeAll()
            }
        }
    }

    private var lastNotified: [String: Date] = [:]

    private init() {}

    func evaluate(metrics: Metrics) {
        guard isEnabled else { return }

        let now = Date()

        check(
            key: "cpu",
            condition: metrics.getCPUUsage() >= thresholds.cpuUsage,
            title: "High CPU Usage",
            body: String(format: "CPU is at %.1f%%", metrics.getCPUUsage()),
            now: now
        )

        check(
            key: "gpu",
            condition: metrics.getGPUUsage() >= thresholds.gpuUsage,
            title: "High GPU Usage",
            body: String(format: "GPU is at %.1f%%", metrics.getGPUUsage()),
            now: now
        )

        check(
            key: "mem",
            condition: metrics.getMemUsage() >= thresholds.memUsage,
            title: "High Memory Usage",
            body: String(
                format: "Memory is at %.1f%% (%.1f GB used)",
                metrics.getMemUsage(),
                metrics.getMemUsed()
            ),
            now: now
        )

        check(
            key: "swap",
            condition: metrics.getSwapUsage() >= thresholds.swapUsage,
            title: "High Swap Usage",
            body: String(
                format: "Swap is at %.1f%% — system may begin to slow down",
                metrics.getSwapUsage()
            ),
            now: now
        )

        check(
            key: "power",
            condition: metrics.allPower >= thresholds.totalPower,
            title: "High Power Draw",
            body: String(
                format: "System is drawing %.1fW — thermal throttling likely",
                metrics.allPower
            ),
            now: now
        )
    }

    private func check(
        key: String,
        condition: Bool,
        title: String,
        body: String,
        now: Date
    ) {
        guard condition else {
            lastNotified.removeValue(forKey: key)
            return
        }

        if let last = lastNotified[key],
            now.timeIntervalSince(last) < thresholds.cooldown
        {
            return
        }

        lastNotified[key] = now
        send(title: title, body: body, identifier: key)
    }

    private func send(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
