//
//  CoreTier.swift
//  StatsBar
//
//  Created by Shashank on 10/10/26.
//
//  Referenced: https://github.com/vladkens/macmon (src/sources.rs, src/metrics.rs)
//  and https://github.com/exelban/stats (Kit/plugins/SystemKit.swift)
//

// hw.nperflevels upper bound; M5 = 2 tiers, M6 = 3
let CORE_TIERS_MAX = 3

enum CoreTier: Int, CaseIterable, Comparable {
    case efficiency
    case performance
    case superCore

    init?(perflevelName: String) {
        switch perflevelName {
        case "Efficiency": self = .efficiency
        case "Performance": self = .performance
        case "Super": self = .superCore
        default: return nil
        }
    }

    init(position: Int, levels: Int) {
        assert(levels >= 1 && levels <= CORE_TIERS_MAX)
        assert(position >= 0 && position < levels)

        // 1 level => performance; 2 => E, P; 3 => E, P, S
        let offset = levels == 1 ? 1 : 0
        self = CoreTier(rawValue: position + offset) ?? .performance
    }

    var short: String {
        switch self {
        case .efficiency: return "E"
        case .performance: return "P"
        case .superCore: return "S"
        }
    }

    var label: String {
        return "\(self.short)-CPU"
    }

    static func < (lhs: CoreTier, rhs: CoreTier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct CoreCluster {
    let tier: CoreTier
    let cores: Int
    let freqs: [UInt32]     // MHz; empty => table not found, usage reported unscaled
    let channel: String     // IOReport channel substring: ECPU | MCPU | PCPU
}

// [(tier, cores)] lowest first; `perflevels` in sysctl order (perflevel0 = highest)
func coreTiers(perflevels: [(name: String?, cores: Int)]) throws -> [(tier: CoreTier, cores: Int)] {
    let levels = perflevels.count

    guard levels >= 1, levels <= CORE_TIERS_MAX else { throw ServiceError.noCpuCores }
    var tiers: [(tier: CoreTier, cores: Int)] = []

    for (level, perflevel) in perflevels.enumerated() {
        guard perflevel.cores > 0 else { throw ServiceError.noCpuCores }

        // unknown name => tier by position, lowest = last perflevel
        let tier = perflevel.name.flatMap { CoreTier(perflevelName: $0) }
        ?? CoreTier(position: levels - 1 - level, levels: levels)

        tiers.append((tier, perflevel.cores))
    }
    tiers.sort { $0.tier < $1.tier }

    guard Set(tiers.map(\.tier)).count == tiers.count else {
        throw ServiceError.unexpectedError(msg: "Duplicate CPU tiers")
    }
    return tiers
}

// IOReport channel substring; with a Super tier, PCPU = Super and MCPU = Performance
func coreTierChannel(tier: CoreTier, hasSuper: Bool) -> String {
    switch tier {
    case .efficiency: return "ECPU"
    case .performance: return hasSuper ? "MCPU" : "PCPU"
    case .superCore: return "PCPU"
    }
}

// pmgr voltage-states keys to try, in order; `accClusters` = raw pmgr "acc-clusters"
func coreTierFreqKeys(tier: CoreTier, hasSuper: Bool, accClusters: [UInt8]) -> [String] {
    switch tier {
    case .efficiency:
        return ["voltage-states1-sram"]
    case .superCore:
        return ["voltage-states5-sram"]
    case .performance:
        if !hasSuper {
            return ["voltage-states5-sram"]
        }

        // M5 Pro/Max: 22 == 23 (two P clusters); then any acc-cluster that isn't E (1) or S (5)
        var keys = ["voltage-states22-sram", "voltage-states23-sram"]
        for key in accClusterKeys(accClusters) where !keys.contains(key) {
            if key == "voltage-states1-sram" || key == "voltage-states5-sram" {
                continue
            }
            keys.append(key)
        }

        // M6: P shares the P-complex table with S
        keys.append("voltage-states5-sram")
        return keys
    }
}

// acc-clusters: 8-byte entries, byte 0 = voltage-states index, byte 1 = cluster ordinal
func accClusterKeys(_ data: [UInt8]) -> [String] {
    // 16 entries far exceeds any known chip (M5 Max = 3)
    let entries_max = 16
    let count = min(data.count / 8, entries_max)
    return (0..<count).map { "voltage-states\(data[$0 * 8])-sram" }
}
