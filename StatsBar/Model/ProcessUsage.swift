//
//  ProcessUsage.swift
//  StatsBar
//
//  Created by Shashank on 23/09/26.
//

import AppKit
import Foundation

struct ProcessUsage: Identifiable {
    let id: String
    let name: String
    let icon: NSImage?
    let pids: [pid_t]
    let cpuPercent: Double
    let memoryBytes: UInt64
    let diskBytesPerSec: UInt64
    let networkBytesPerSec: UInt64
}
