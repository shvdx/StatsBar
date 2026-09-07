//
//  SettingsMenu.swift
//  StatsBar
//
//  Created by Shashank on 07/09/26.
//

import LaunchAtLogin
import SwiftUI
import UserNotifications

struct SettingsMenu: View {

    @AppStorage(NotificationManager.enabledKey) private
        var notificationsEnabled = true

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.expanded.toggle()
                }
            } label: {
                HStack {
                    Text("Settings")
                        .font(.jb(.callout))
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "gearshape")
                        .font(.jb(.caption))
                    Image(systemName: self.expanded ? "chevron.up" : "chevron.down")
                        .font(.jb(.caption))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if self.expanded {
                VStack(alignment: .leading, spacing: 6) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
