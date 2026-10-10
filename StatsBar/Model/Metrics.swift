//
//  Metrics.swift
//  StatsBar
//
//  Created by Shashank on 14/11/24.
//

import CoreFoundation
import Foundation
import IOKit

struct ClusterUsage {
    let tier: CoreTier
    let freq: UInt32        // MHz
    let usage: Float32      // 0...1
    let cores: [Float32]    // per-core usage 0...1
}

struct Metrics {
    // lowest tier first, SOCInfo.clusters order
    let clusters: [ClusterUsage]
    let gpuUsage: (UInt32, Float32)
    let cpuPower: Float32
    let gpuPower: Float32
    let anePower: Float32
    let sysPower: Float32
    let memUsage: (UInt64, UInt64)
    let swapUsage: (UInt64, UInt64)
    let networkUsage: (upload: Int64, download: Int64)
    let diskUsage: [String: (read: Int64, write: Int64)]

    init(
        clusters: [ClusterUsage],
        gpuUsage: (UInt32, Float32),
        cpuPower: Float32,
        gpuPower: Float32,
        anePower: Float32,
        sysPower: Float32,
        memUsage: (UInt64, UInt64),
        swapUsage: (UInt64, UInt64),
        networkUsage: (Int64, Int64),
        diskUsage: [String: (read: Int64, write: Int64)]
    ) {
        assert(clusters.count <= CORE_TIERS_MAX)
        self.clusters = clusters
        self.gpuUsage = gpuUsage
        self.cpuPower = cpuPower
        self.gpuPower = gpuPower
        self.anePower = anePower
        self.sysPower = sysPower
        self.memUsage = memUsage
        self.swapUsage = swapUsage
        self.networkUsage = networkUsage
        self.diskUsage = diskUsage
    }

    // unweighted mean over clusters, %
    func getCPUUsage() -> Double {
        guard !self.clusters.isEmpty else { return 0 }
        let sum = self.clusters.reduce(0.0) { $0 + Double($1.usage) }
        return sum * 100 / Double(self.clusters.count)
    }

    // [usage %, freq GHz]
    func getClusterInfo(_ index: Int) -> [Double] {
        assert(index < self.clusters.count)
        let cluster = self.clusters[index]
        return [Double(cluster.usage * 100), Double(cluster.freq) / 1000.0]
    }

    func getGPUFreq() -> Double {
        return Double(self.gpuUsage.0) / 1000.0
    }

    func getGPUUsage() -> Double {
        return Double(self.gpuUsage.1) * 100
    }

    func getMemUsed() -> Double {
        return Double(self.memUsage.0) / 1024.0 / 1024.0 / 1024.0
    }

    func getMemUsage() -> Double {
        return Double(self.getMemUsed() * 100) / Double(self.getTotalMemory())
    }

    func getTotalMemory() -> UInt64 {
        return self.memUsage.1 / 1024 / 1024 / 1024
    }

    func getSwapUsage() -> Double {
        // ratio from raw bytes; getTotalSwap() truncates to GB => 0 => +Inf
        let total = self.swapUsage.1
        guard total > 0 else { return 0 }
        return Double(self.swapUsage.0) * 100 / Double(total)
    }

    func getSwapUsed() -> Double {
        return Double(self.swapUsage.0) / 1024.0 / 1024.0 / 1024.0
    }

    func getTotalSwap() -> UInt64 {
        return self.swapUsage.1 / 1024 / 1024 / 1024
    }

    func getDiskRead(key: String) -> Int64 {
        return self.diskUsage[key]?.read ?? 0
    }

    func getDiskWrite(key: String) -> Int64 {
        return self.diskUsage[key]?.write ?? 0
    }
}
