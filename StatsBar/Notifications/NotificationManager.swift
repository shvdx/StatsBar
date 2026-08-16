//
//  NotificationManager.swift
//  StatsBar
//

import Foundation
import UserNotifications

struct AlertThresholds {
    var cpuUsage: Double = 99.0  // %
    var memUsage: Double = 95.0  // %
    var totalPower: Float32 = 30.0  // Watts (system power)
    var ttl: TimeInterval = 60.0  // seconds
    var sustainSamples = 7  // consecutive breaches
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
                breaches.removeAll()
                lastNotified = nil
            }
        }
    }

    private var breaches: [String: Int] = [:]
    private var lastNotified: Date?

    private init() {}

    func evaluate(metrics: Metrics) {
        guard isEnabled else { return }

        let now = Date()
        let cpu = metrics.getCPUUsage()
        let ram = metrics.getMemUsage()
        let power = metrics.sysPower

        track(key: "cpu", breached: cpu >= thresholds.cpuUsage)
        track(key: "ram", breached: ram >= thresholds.memUsage)
        track(key: "power", breached: power >= thresholds.totalPower)

        if let last = lastNotified, now.timeIntervalSince(last) < thresholds.ttl {
            return
        }

        if breaches["cpu", default: 0] >= thresholds.sustainSamples {
            notify(
                key: "cpu",
                title: "High CPU Usage",
                body: String(format: "CPU is at %.1f%%", cpu),
                now: now
            )
            return
        }

        if breaches["ram", default: 0] >= thresholds.sustainSamples {
            notify(
                key: "ram",
                title: "High Memory Usage",
                body: String(
                    format: "Memory is at %.1f%% (%.1f GB used)",
                    ram,
                    metrics.getMemUsed()
                ),
                now: now
            )
            return
        }

        if breaches["power", default: 0] >= thresholds.sustainSamples {
            notify(
                key: "power",
                title: "High Power Draw",
                body: String(
                    format: "System is drawing %.1fW — thermal throttling likely",
                    power
                ),
                now: now
            )
            return
        }
    }

    private func track(key: String, breached: Bool) {
        if breached {
            breaches[key] = min(
                breaches[key, default: 0] + 1,
                thresholds.sustainSamples
            )
        } else {
            breaches[key] = 0
        }
    }

    private func notify(key: String, title: String, body: String, now: Date) {
        lastNotified = now
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
