//
//  MenuView.swift
//  StatsBar
//
//  Created by Shashank on 25/11/24.
//

import AppKit
import Charts
import Collections
import LaunchAtLogin
import SwiftUI
import UserNotifications

extension Color {
    func adaptedTextColor(_ env: EnvironmentValues) -> Color {
        let components = self.resolve(in: env)
        let luminance =
            0.2126 * Double(components.red) + 0.7152 * Double(components.green)
            + 0.0722 * Double(components.blue)

        return luminance > 0.5 ? Color.black : Color.white
    }
}

struct MenuView: View {
    @Environment(\.self) var environment

    let engine: MetricsEngine
    @AppStorage(NotificationManager.enabledKey) private
        var notificationsEnabled = true

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.engine.toggle()
                }) {
                    Label(
                        self.engine.isRunning ? "Stop" : "Start",
                        systemImage: self.engine.isRunning ? "stop" : "play"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .clipShape(
                    RoundedRectangle(cornerSize: CGSize(width: 8, height: 8))
                )

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit App", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .clipShape(
                    RoundedRectangle(cornerSize: CGSize(width: 8, height: 8))
                )

                Spacer()

                Toggle("Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        NotificationManager.shared.isEnabled = enabled
                        if enabled {
                            UNUserNotificationCenter.current()
                                .requestAuthorization(options: [.alert, .sound]) { _, _ in }
                        }
                    }

                LaunchAtLogin.Toggle("Launch at login")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if case .failed(let message) = self.engine.status {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.callout)
                    Spacer()
                    Button("Retry") {
                        self.engine.start()
                    }
                }
                .padding(8)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
            }

            if let metrics = self.engine.metrics {
                ScrollView {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal, 12)

                        CPUView(
                            socInfo: self.engine.socInfo,
                            metrics: metrics,
                            usageGraph: self.engine.usageGraph
                        )
                        .padding(.horizontal, 12)

                        Divider()
                            .padding(.horizontal, 12)

                        MemView(
                            metrics: metrics,
                            usageGraph: self.engine.usageGraph
                        )
                        .padding(.horizontal, 12)

                        Divider()
                            .padding(.horizontal, 12)

                        PowerView(metrics: metrics)
                            .padding(.horizontal, 12)

                        Divider()
                            .padding(.horizontal, 12)

                        NetworkView(
                            network: self.engine.network,
                            metrics: metrics,
                            usageGraph: self.engine.usageGraph
                        )
                        .padding(.horizontal, 12)

                        Divider()
                            .padding(.horizontal, 12)

                        DiskView(
                            metrics: metrics,
                            disks: self.engine.disks,
                            diskUsageGraph: self.engine.diskUsageGraph
                        )
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
    }
}
