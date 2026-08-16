//
//  AppDelegate.swift
//  StatsBar
//
//  Created by Shashank on 11/11/24.
//

import SwiftUI
import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = MetricsEngine()
    private var statusItem: NSStatusItem?
    private var glyph: NSHostingView<PopupText>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.close()
        }

        if UserDefaults.standard.object(forKey: NotificationManager.enabledKey) as? Bool ?? true {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        self.setupMenu()
    }

    private func setupMenu() {
        let menuView = NSHostingView(rootView: MenuView(engine: self.engine))
        menuView.frame = NSRect(x: 0, y: 0, width: 620, height: 620)

        let menuItem = NSMenuItem()
        menuItem.view = menuView

        let menu = NSMenu()
        menu.addItem(menuItem)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        self.statusItem = statusItem

        if let button = statusItem.button {
            let glyph = NSHostingView(rootView: PopupText(engine: self.engine))
            glyph.frame = button.bounds
            glyph.autoresizingMask = [.width, .height]
            button.addSubview(glyph)
            self.glyph = glyph
        }

        self.resizeGlyph()
        self.observeGlyphWidth()
    }

    private func resizeGlyph() {
        self.statusItem?.length = self.engine.metrics == nil ? 72 : POPUP_VIEW_HEIGHT * 10
    }

    private func observeGlyphWidth() {
        withObservationTracking {
            _ = self.engine.metrics
        } onChange: {
            Task { @MainActor in
                self.resizeGlyph()
                if self.engine.metrics == nil {
                    self.observeGlyphWidth()
                }
            }
        }
    }
}
