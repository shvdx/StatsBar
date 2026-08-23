//
//  ProcessSampler.swift
//  StatsBar
//

import Darwin
import Foundation

// Per-app aggregation produced off the main thread via libproc rusage. Names and
// icons are resolved later on the main actor (AppKit), so nothing here touches
// NSRunningApplication. Rows are keyed by the *responsible* pid, so an app's
// helper processes (WebKit, XPC) collapse into their parent app.
struct RawProcessUsage {
    let responsiblePid: pid_t
    let command: String
    let pids: [pid_t]
    let cpuPercent: Double
    let memoryBytes: UInt64
    let diskBytesPerSec: UInt64
}

final class ProcessSampler {

    // Bound everything: the pid enumeration buffer and the returned row count.
    private static let processes_max = 4096
    private static let rows_max = 256

    // false => one row per pid (raw); true => fold helpers into their parent app.
    private static let group_by_app = false

    private var prevByPid: [pid_t: Prev] = [:]
    private var prevUptimeNs: UInt64?

    private struct Usage {
        let cpuNs: UInt64
        let footprint: UInt64
        let diskBytes: UInt64
    }

    private struct Prev {
        let cpuNs: UInt64
        let diskBytes: UInt64
    }

    private struct Accum {
        let command: String
        var pids: [pid_t]
        var cpuPercent: Double
        var memoryBytes: UInt64
        var diskBytesPerSec: UInt64
    }

    func sample() throws -> [RawProcessUsage] {
        let nowNs = DispatchTime.now().uptimeNanoseconds
        let dtNs = self.prevUptimeNs.map { nowNs - $0 }
        if let dtNs { assert(dtNs > 0) }

        let pids = try self.listPids()
        assert(pids.count <= Self.processes_max)

        var accums: [pid_t: Accum] = [:]
        var liveByPid: [pid_t: Prev] = [:]
        var commands: [pid_t: String] = [:]

        for pid in pids where pid > 0 {
            // EPERM on protected/root pids: cannot read usage, so cannot rank.
            guard let usage = Self.readUsage(pid: pid) else { continue }
            liveByPid[pid] = Prev(cpuNs: usage.cpuNs, diskBytes: usage.diskBytes)

            let rates = Self.rates(usage: usage, prev: self.prevByPid[pid], dtNs: dtNs)
            let rpid = Self.group_by_app ? Self.responsiblePid(for: pid) : pid
            if commands[rpid] == nil { commands[rpid] = Self.command(pid: rpid) }

            var accum =
                accums[rpid]
                ?? Accum(
                    command: commands[rpid] ?? "pid \(rpid)",
                    pids: [],
                    cpuPercent: 0,
                    memoryBytes: 0,
                    diskBytesPerSec: 0
                )
            accum.pids.append(pid)
            accum.cpuPercent += rates.cpuPercent
            accum.memoryBytes += usage.footprint
            accum.diskBytesPerSec += rates.diskBytesPerSec
            accums[rpid] = accum
        }

        self.prevByPid = liveByPid  // Prune dead pids; keep only what we just saw.
        self.prevUptimeNs = nowNs

        return Self.rows(from: accums)
    }

    private func listPids() throws -> [pid_t] {
        var pids = [pid_t](repeating: 0, count: Self.processes_max)
        let size = Int32(Self.processes_max * MemoryLayout<pid_t>.size)
        let bytes = proc_listallpids(&pids, size)
        guard bytes > 0 else {
            throw ServiceError.unexpectedError(msg: "proc_listallpids failed")
        }

        let count = min(Int(bytes) / MemoryLayout<pid_t>.size, Self.processes_max)
        assert(count >= 0)
        return Array(pids.prefix(count))
    }

    private static func readUsage(pid: pid_t) -> Usage? {
        assert(pid > 0)

        var info = rusage_info_v4()
        let rc = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard rc == 0 else { return nil }

        return Usage(
            cpuNs: info.ri_user_time + info.ri_system_time,
            footprint: info.ri_phys_footprint,
            diskBytes: info.ri_diskio_bytesread + info.ri_diskio_byteswritten
        )
    }

    private static func rates(
        usage: Usage,
        prev: Prev?,
        dtNs: UInt64?
    ) -> (cpuPercent: Double, diskBytesPerSec: UInt64) {
        guard let prev, let dtNs, dtNs > 0 else { return (0, 0) }

        // Counters are cumulative and monotonic; clamp against pid reuse anyway.
        let cpuDeltaNs = usage.cpuNs >= prev.cpuNs ? usage.cpuNs - prev.cpuNs : 0
        let diskDelta =
            usage.diskBytes >= prev.diskBytes
            ? usage.diskBytes - prev.diskBytes : 0

        let cpuPercent = Double(cpuDeltaNs) / Double(dtNs) * 100.0
        let dtSec = Double(dtNs) / 1_000_000_000.0
        let diskRate = dtSec > 0 ? UInt64(Double(diskDelta) / dtSec) : 0
        return (cpuPercent, diskRate)
    }

    private static func responsiblePid(for pid: pid_t) -> pid_t {
        assert(pid > 0)
        let rpid = responsibility_get_pid_responsible_for_pid(pid)
        return rpid > 0 ? rpid : pid
    }

    private static func command(pid: pid_t) -> String {
        assert(pid > 0)
        var buffer = [CChar](repeating: 0, count: 256)
        let len = proc_name(pid, &buffer, UInt32(buffer.count))
        guard len > 0 else { return "pid \(pid)" }
        return String(cString: buffer)
    }

    private static func rows(from accums: [pid_t: Accum]) -> [RawProcessUsage] {
        let rows = accums.map { rpid, accum in
            RawProcessUsage(
                responsiblePid: rpid,
                command: accum.command,
                pids: accum.pids,
                cpuPercent: accum.cpuPercent,
                memoryBytes: accum.memoryBytes,
                diskBytesPerSec: accum.diskBytesPerSec
            )
        }

        // Cap the returned set (well above the real app count) to bound the work
        // the main actor does resolving icons; keep the busiest by CPU.
        let capped = rows.sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(Self.rows_max)
        return Array(capped)
    }
}
