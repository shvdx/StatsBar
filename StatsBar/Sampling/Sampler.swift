//
//  Sampler.swift
//  StatsBar
//
//  Created by Shashank on 24/11/24.
//

import Foundation

private let CPU_FREQ_SUBG = "CPU Core Performance States"
private let GPU_FREQ_SUBG = "GPU Performance States"

private struct CoreSample {
    // per cluster, SOCInfo.clusters order
    let clusters: [(freq: UInt32, usage: Float32)]
    let cores: [[Float32]]
    let gpuUsage: (UInt32, Float32)
    let cpuPower: Float32
    let gpuPower: Float32
    let anePower: Float32
}

struct Sampler {

    let socInfo: SOCInfo
    let ior: IOReport
    let smc: SMC
    let network: Network
    let disk: Disk
    let memory: Memory
    let processes: ProcessSampler

    private static let measures = 4

    init() throws {
        self.socInfo = try SOCInfo()
        self.ior = try IOReport()
        self.smc = try SMC()
        self.network = Network()
        self.disk = Disk()
        self.memory = Memory()
        self.processes = ProcessSampler()
    }

    func getMetrics() async throws -> Metrics {
        try self.disk.updateDiskSpaceStats()

        let sampleData = try await self.ior.getSamples(measures: Self.measures)
        let cores = sampleData.map { (samples, dt) in
            self.coreSample(samples: samples, dt: dt)
        }

        return try self.aggregate(cores: cores)
    }

    private func coreSample(samples: [IOSample], dt: TimeInterval) -> CoreSample {
        let clusters = self.socInfo.clusters

        // per-core (freq, usage) per cluster; count doubles as the next core index
        var usages = clusters.map { _ in [(UInt32, Float32)]() }
        var cores = clusters.map { [Float32](repeating: 0, count: $0.cores) }
        var gpuUsage: (UInt32, Float32) = (0, 0)
        var cpuPower = Float32(0)
        var gpuPower = Float32(0)
        var anePower = Float32(0)

        for sample in samples {
            if sample.group == "CPU Stats" && sample.subGroup == CPU_FREQ_SUBG {
                // contains, not prefix: Ultra channels carry a DIE_n_ prefix
                if let index = clusters.firstIndex(where: { sample.channel.contains($0.channel) }) {
                    let core = usages[index].count
                    if core < cores[index].count {
                        let info = self.calculateFrequencies(
                            dict: sample.delta,
                            freqs: clusters[index].freqs
                        )
                        usages[index].append(info)
                        cores[index][core] = info.usage
                    }
                    continue
                }
            }

            if sample.group == "GPU Stats" && sample.subGroup == GPU_FREQ_SUBG
                && sample.channel == "GPUPH"
            {
                gpuUsage = self.calculateFrequencies(
                    dict: sample.delta,
                    freqs: Array(self.socInfo.gpuFreqs.dropFirst(1))
                )
                continue
            }

            if sample.group == "Energy Model" {
                let watts = self.calculateWatts(
                    dict: sample.delta,
                    unit: sample.unit,
                    duration: UInt64(dt.magnitude)
                )
                if sample.channel == "CPU Energy" {
                    cpuPower += watts
                }
                if sample.channel == "GPU Energy" {
                    gpuPower += watts
                }
                if sample.channel.starts(with: "ANE") {
                    anePower += watts
                }
            }
        }

        return CoreSample(
            clusters: clusters.indices.map {
                self.calculateAggregateFrequencies(items: usages[$0], freqs: clusters[$0].freqs)
            },
            cores: cores,
            gpuUsage: gpuUsage,
            cpuPower: cpuPower,
            gpuPower: gpuPower,
            anePower: anePower
        )
    }

    private func aggregate(cores: [CoreSample]) throws -> Metrics {
        let measures = Float32(Self.measures)
        assert(cores.count == Self.measures)

        let clusters = self.socInfo.clusters.indices.map { index in
            let cluster = self.socInfo.clusters[index]
            let usages = (0..<cluster.cores).map { core in
                cores.reduce(0, { $0 + $1.cores[index][core] }) / measures
            }
            return ClusterUsage(
                tier: cluster.tier,
                freq: cores.reduce(0, { $0 + $1.clusters[index].freq }) / UInt32(Self.measures),
                usage: cores.reduce(0, { $0 + $1.clusters[index].usage }) / measures,
                cores: usages
            )
        }

        return Metrics(
            clusters: clusters,
            gpuUsage: (
                cores.reduce(0, { $0 + $1.gpuUsage.0 }) / UInt32(Self.measures),
                cores.reduce(0, { $0 + $1.gpuUsage.1 }) / measures
            ),
            cpuPower: cores.reduce(0, { $0 + $1.cpuPower }),
            gpuPower: cores.reduce(0, { $0 + $1.gpuPower }),
            anePower: cores.reduce(0, { $0 + $1.anePower }),
            sysPower: try self.smc.readPSTR(),
            memUsage: try self.memory.getMemUsage(),
            swapUsage: try self.memory.getSwap(),
            networkUsage: try self.network.readStats(),
            diskUsage: self.disk.readDriveStats()
        )
    }

    private func calculateFrequencies(dict: CFDictionary, freqs: [UInt32]) -> (
        freq: UInt32, usage: Float32
    ) {
        let items = getResidencies(dict: dict)

        let offset = items.firstIndex { (x, _) in
            return x != "IDLE" && x != "DOWN" && x != "OFF"
        }
        guard let offset else {
            return (0, 0)
        }
        let usage = items.dropFirst(offset).reduce(0.0) { $0 + Double($1.f) }
        let total = items.reduce(0.0) { $0 + Double($1.f) }
        let usageRatio = total == 0 ? 0 : usage / total

        // no freq table (unknown chip) => residency ratio only
        guard let minFreq = freqs.first, let maxFreq = freqs.last else {
            return (0, Float32(usageRatio))
        }
        let count = freqs.count

        var avgFreq = Double(0)
        for i in 0..<count where i + offset < items.count {
            let percent = usage == 0 ? 0 : Double(items[i + offset].f) / usage
            avgFreq += percent * Double(freqs[i])
        }

        let fromMax = (max(avgFreq, Double(minFreq)) * usageRatio) / Double(maxFreq)

        let freq = avgFreq.isFinite ? min(max(avgFreq, 0), Double(UInt32.max)) : 0
        return (UInt32(freq), Float32(fromMax))
    }

    private func calculateAggregateFrequencies(
        items: [(UInt32, Float32)],
        freqs: [UInt32]
    ) -> (UInt32, Float32) {
        let avgFreq = items.count == 0 ? 0 : (items.reduce(0.0, { $0 + Float32($1.0) }) / Float32(items.count))
        let avgPrec = items.count == 0 ? 0 : (items.reduce(0.0, { $0 + Float32($1.1) }) / Float32(items.count))
        let minFreq = Float32(freqs.first ?? 0)

        return (UInt32(max(avgFreq, minFreq)), avgPrec)
    }

    private func calculateWatts(
        dict: CFDictionary,
        unit: String,
        duration: UInt64
    ) -> Float32 {
        let val = IOReportSimpleGetIntegerValue(dict, 0)
        let watts = Float32(val) / (Float32(duration) / 1000.0)
        switch unit {
        case "mJ":
            return watts / 1e3
        case "uJ":
            return watts / 1e6
        case "nJ":
            return watts / 1e9
        default:
            return 0
        }
    }

    private func getResidencies(dict: CFDictionary) -> [(ns: String, f: Int64)] {
        let count = IOReportStateGetCount(dict)

        var res = [(String, Int64)]()

        for i in 0..<count {
            let name =
            IOReportStateGetNameForIndex(dict, i)?.takeUnretainedValue()
            ?? ("" as CFString)

            let val = IOReportStateGetResidency(dict, i)
            res.append((name as String, val))
        }

        return res
    }
}
