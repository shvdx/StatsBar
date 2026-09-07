//
//  AppDelegate.swift
//  StatsBar
//
//  Created by Shashank on 11/11/24.
//

import AppKit
import CoreText
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = MetricsEngine()
    private var statusItem: NSStatusItem?
    private var glyph: NSHostingView<PopupText>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.registerFonts()
        LocationAuth.shared.request()

        if let window = NSApplication.shared.windows.first {
            window.close()
        }

        if UserDefaults.standard.object(forKey: NotificationManager.enabledKey)
            as? Bool ?? true
        {
            UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert, .sound,
            ]) { _, _ in }
        }

        self.setupMenu()
    }

    // Bundled fonts aren't auto-registered; make JetBrains Mono resolvable by name.
    private static func registerFonts() {
        guard
            let urls = Bundle.main.urls(
                forResourcesWithExtension: "ttf",
                subdirectory: nil
            )
        else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }

    private func setupMenu() {
        let menuView = NSHostingView(rootView: MenuView(engine: self.engine))
        let heightMax = (NSScreen.main?.visibleFrame.height ?? 800) - 24
        menuView.frame = NSRect(
            x: 0,
            y: 0,
            width: 320,
            height: min(800, heightMax)
        )

        let menuItem = NSMenuItem()
        menuItem.view = menuView

        let menu = NSMenu()
        menu.addItem(menuItem)

        let statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
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
        if case .failed = self.engine.status {
            self.statusItem?.length = 96
            return
        }
        self.statusItem?.length =
            self.engine.metrics == nil ? 72 : POPUP_VIEW_HEIGHT * 10
    }

    private func observeGlyphWidth() {
        withObservationTracking {
            _ = self.engine.metrics
            _ = self.engine.status
        } onChange: {
            Task { @MainActor in
                self.resizeGlyph()
                self.observeGlyphWidth()
            }
        }
    }
}
