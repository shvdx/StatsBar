//
//  LocationAuth.swift
//  StatsBar
//
//  Created by Shashank on 08/09/26.
//

import CoreLocation

// Wi-Fi SSID is location-gated on macOS 14+; holding auth unlocks CWInterface.ssid().
// The next sampling tick re-reads the SSID once the user grants the prompt.
final class LocationAuth: NSObject, CLLocationManagerDelegate {

    static let shared = LocationAuth()

    private let manager = CLLocationManager()
    private(set) var status: CLAuthorizationStatus = .notDetermined

    // true once auth allows reading the SSID; false => the name stays hidden.
    // macOS only grants .authorizedAlways (no when-in-use tier).
    var isAuthorized: Bool {
        self.status == .authorizedAlways
    }

    override init() {
        super.init()
        self.manager.delegate = self
        self.status = self.manager.authorizationStatus
    }

    func request() {
        self.manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.status = manager.authorizationStatus
    }
}
