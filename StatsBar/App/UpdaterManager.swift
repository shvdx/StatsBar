//
//  UpdaterManager.swift
//  StatsBar
//
//  Created by Shashank on 08/09/26.
//

import Combine
import Sparkle

// Sparkle auto-update. SUFeedURL + SUPublicEDKey are read from Info.plist.
@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    private let controller: SPUStandardUpdaterController

    // drives the "Check for Updates" row enabled state
    @Published private(set) var canCheckForUpdates = false

    private var cancellable: AnyCancellable?

    private init() {
        // startingUpdater: true => schedules background checks per Info.plist
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.cancellable =
            self.controller.updater
            .publisher(for: \.canCheckForUpdates)
            .sink { [weak self] can in
                self?.canCheckForUpdates = can
            }
    }

    func checkForUpdates() {
        self.controller.updater.checkForUpdates()
    }
}
