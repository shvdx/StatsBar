//
//  SOCInfo.swift
//  StatsBar
//
//  Created by Shashank on 14/11/24.
//

import CoreFoundation
import Foundation
import IOKit

struct SOCInfo {
    // lowest tier first
    let clusters: [CoreCluster]
    let gpuFreqs: [UInt32]

    let chipName: String
    let macModel: String
    let memorySize: Int  // GB
    let gpuCores: Int

    init() throws {
        let m3Below = try Regex("[m|M][1-3]")
        let services = try getIOServices(service: SERVICE_NAME)

        // M1–M5: tables on "pmgr"; M6+: on "pmgr-child", "pmgr" is a bare stub
        let nodes = services.filter { $0.name == "pmgr" || $0.name == "pmgr-child" }
        guard !nodes.isEmpty else {
            throw ServiceError.powerManagerRegistryNotFound
        }

        let dicts: [[String: Any]] = nodes.compactMap { node in
            var props: Unmanaged<CFMutableDictionary>?
            _ = IORegistryEntryCreateCFProperties(node.next, &props, kCFAllocatorDefault, 0)
            return props?.takeRetainedValue() as? [String: Any]
        }
        guard !dicts.isEmpty else {
            throw ServiceError.dictionaryNull(for: "Power manager")
        }

        let sysInfo = try runSystemProfiler()

        self.chipName = sysInfo.spHardwareDataType[0].chip_type
        self.macModel = sysInfo.spHardwareDataType[0].machine_model
        self.memorySize =
            Int(
                sysInfo.spHardwareDataType[0].physical_memory.split(
                    separator: " GB"
                )[0]
            ) ?? 0

        self.gpuCores = Int(sysInfo.spDisplaysDataType[0].sppci_cores) ?? 0

        // tiers from sysctl, not number_processors: its field order changed in macOS 26 and 27
        let tiers = try readCoreTiers()
        let hasSuper = tiers.contains { $0.tier == .superCore }
        let isM3Below = chipName.contains(m3Below)
        let accClusters =
            dicts.lazy.compactMap { $0["acc-clusters"] as? Data }.first.map {
                [UInt8]($0)
            } ?? []

        self.clusters = tiers.map { tier, cores in
            CoreCluster(
                tier: tier,
                cores: cores,
                freqs: firstFreq(
                    dicts: dicts,
                    keys: coreTierFreqKeys(
                        tier: tier,
                        hasSuper: hasSuper,
                        accClusters: accClusters
                    ),
                    isM3Below: isM3Below
                ),
                channel: coreTierChannel(tier: tier, hasSuper: hasSuper)
            )
        }
        assert(!self.clusters.isEmpty)

        // GPU tables are Hz on every chip; none => usage unscaled, not a startup failure
        self.gpuFreqs = firstFreq(
            dicts: dicts,
            keys: ["voltage-states9-sram", "voltage-states9"],
            isM3Below: true
        )
    }
}

// hw.perflevelN.{name,physicalcpu}, perflevel0 first
private func readCoreTiers() throws -> [(tier: CoreTier, cores: Int)] {
    guard let levels = sysctlInt("hw.nperflevels"), levels >= 1, levels <= CORE_TIERS_MAX else {
        throw ServiceError.noCpuCores
    }
    var perflevels: [(name: String?, cores: Int)] = []
    for level in 0..<levels {
        guard let cores = sysctlInt("hw.perflevel\(level).physicalcpu") else {
            throw ServiceError.noCpuCores
        }
        perflevels.append((sysctlString("hw.perflevel\(level).name"), cores))
    }
    return try coreTiers(perflevels: perflevels)
}

// first key (in order) holding a non-empty table in any node; none => [] (usage unscaled, freq 0)
func firstFreq(dicts: [[String: Any]], keys: [String], isM3Below: Bool) -> [UInt32] {
    for key in keys {
        for dict in dicts where dict[key] != nil {
            if let freqs = try? getFreq(dict: dict, key: key, isM3Below: isM3Below),
                !freqs.isEmpty
            {
                return freqs
            }
        }
    }
    return []
}

private func sysctlInt(_ name: String) -> Int? {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size

    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    guard size == MemoryLayout<Int32>.size else { return nil }
    return Int(value)
}

private func sysctlString(_ name: String) -> String? {
    // perflevel names are short ("Efficiency"); bound the buffer
    let size_max = 64
    var size = 0

    guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
    guard size > 0, size <= size_max else { return nil }

    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
}

private func getFreq(dict: [String: Any], key: String, isM3Below: Bool) throws
    -> [UInt32]
{
    guard let value = dict[key] else {
        throw ServiceError.dictionaryNull(for: key)
    }
    guard CFGetTypeID(value as CFTypeRef) == CFDataGetTypeID() else {
        throw ServiceError.unexpectedError(msg: "Unexpected type for \(key)")
    }

    let data = value as! CFData

    let length = CFDataGetLength(data)
    var bytes = [UInt8](repeating: 0, count: length)
    CFDataGetBytes(data, CFRange(location: 0, length: length), &bytes)

    let scale: UInt32 = isM3Below ? 1000 * 1000 : 1000
    var freqs: [UInt32] = []
    //        var volts: [UInt32] = []

    var chunks = stride(from: 0, to: bytes.count, by: 8).map {
        Array(bytes[$0..<min($0 + 8, bytes.count)])
    }
    for chunk in chunks {
        //            volts.append(UInt32(chunk[4]) | UInt32(chunk[5]) << 8 | UInt32(chunk[6]) << 16 | UInt32(chunk[7]) << 24)

        if chunk.count < 4 {
            continue
        }

        let f =
            UInt32(chunk[0]) | UInt32(chunk[1]) << 8 | UInt32(chunk[2]) << 16
            | UInt32(chunk[3]) << 24
        freqs.append(f / scale)  // MHz
    }

    bytes.removeAll()
    chunks.removeAll()

    return freqs
}

private let SERVICE_NAME = "AppleARMIODevice"

struct SPDisplaysDataType: Decodable {
    let name: String
    let spdisplays_mtlgpufamilysupport: String
    let spdisplays_vendor: String
    let sppci_bus: String
    let sppci_cores: String
    let sppci_device_type: String
    let sppci_model: String

    enum CodingKeys: String, CodingKey {
        case name = "_name"
        case spdisplays_mtlgpufamilysupport, spdisplays_vendor, sppci_bus,
            sppci_cores, sppci_device_type, sppci_model
    }
}

struct SPHardwareDataType: Decodable {
    let _name: String
    let chip_type: String
    let machine_model: String
    let machine_name: String
    let model_number: String
    let number_processors: String
    let os_loader_version: String
    let physical_memory: String
    let platform_UUID: String
    let provisioning_UDID: String
    let serial_number: String
}

struct ProfilerResponse: Decodable {
    let spDisplaysDataType: [SPDisplaysDataType]
    let spHardwareDataType: [SPHardwareDataType]

    enum CodingKeys: String, CodingKey {
        case spDisplaysDataType = "SPDisplaysDataType"
        case spHardwareDataType = "SPHardwareDataType"
    }
}

func runSystemProfiler() throws -> ProfilerResponse {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.standardInput = nil
    task.arguments = [
        "-c", "system_profiler SPHardwareDataType SPDisplaysDataType -json",
    ]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")

    try task.run()

    guard let data = try pipe.fileHandleForReading.readToEnd() else {
        throw ServiceError.failedToReadPipe
    }

    do {
        let json = try JSONDecoder().decode(ProfilerResponse.self, from: data)
        return json
    } catch {
        throw ServiceError.failedDeserialization
    }
}
