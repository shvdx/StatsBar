//
//  MetricsEngine.swift
//  StatsBar
//
//  Created by Shashank on 16/08/25.
//

import AppKit
import Collections
import Foundation

enum EngineStatus: Equatable {
    case idle
    case running
    case failed(String)
}

@MainActor
@Observable
final class MetricsEngine {

    private(set) var metrics: Metrics?
    private(set) var processes: [ProcessUsage] = []
    private(set) var disks: OrderedDictionary<String, Drive> = [:]
    private(set) var usageGraph: Deque<UsagePoint> = UsagePoint.mockData()
    private(set) var diskUsageGraph: OrderedDictionary<String, Deque<DiskUsagePoint>> = [:]
    private(set) var status: EngineStatus = .idle

    private var sampler: Sampler?
    private var task: Task<Void, Never>?
    private var sample_failures = 0

    // 500 ms idle + ~500 ms sampling window in getMetrics() => ~1 update/sec.
    private static let sample_interval_ms = 500
    private static let sample_failures_max = 3

    var isRunning: Bool {
        return self.task != nil
    }

    var socInfo: SOCInfo? {
        return self.sampler?.socInfo
    }

    var network: Network? {
        return self.sampler?.network
    }

    func toggle() {
        if self.isRunning {
            self.stop()
        } else {
            self.start()
        }
    }

    func start() {
        assert(self.task == nil)
        assert(self.sampler == nil)

        let sampler: Sampler
        do {
            sampler = try Sampler()
        } catch {
            self.status = .failed(Self.message(for: error))
            return
        }

        self.sampler = sampler
        self.sample_failures = 0
        self.status = .running

        // Sample off the main thread; hop back to apply/fail for state mutation.
        self.task = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        for: .milliseconds(Self.sample_interval_ms),
                        tolerance: .zero
                    )
                    let metrics = try await sampler.getMetrics()
                    let disks = sampler.disk.getDisks()
                    let processes = try sampler.processes.sample()

                    if Task.isCancelled {
                        return
                    }
                    await self?.apply(
                        metrics: metrics,
                        disks: disks,
                        processes: processes
                    )
                } catch is CancellationError {
                    return
                } catch {
                    let recovered = await self?.recordFailure(error) ?? false
                    if recovered {
                        continue
                    }
                    return
                }
            }
        }
    }

    func stop() {
        self.teardown()
        self.status = .idle
    }

    private func teardown() {
        self.task?.cancel()
        self.task = nil
        self.sampler = nil
    }

    private func recordFailure(_ error: Error) -> Bool {
        self.sample_failures += 1
        assert(self.sample_failures <= Self.sample_failures_max)

        if self.sample_failures < Self.sample_failures_max {
            return true
        }

        self.teardown()
        self.status = .failed(Self.message(for: error))
        return false
    }

    private static func message(for error: Error) -> String {
        return (error as? ServiceError)?.getMessage() ?? error.localizedDescription
    }

    private func apply(
        metrics: Metrics,
        disks: OrderedDictionary<String, Drive>,
        processes: [RawProcessUsage]
    ) {
        assert(self.usageGraph.count <= GRAPH_POINTS_MAX)

        self.sample_failures = 0
        self.disks = disks
        self.metrics = metrics
        self.processes = Self.resolve(processes: processes)

        // Drop graphs for disks that went away; trim the survivors.
        for (key, var usage) in self.diskUsageGraph {
            if disks[key] == nil {
                self.diskUsageGraph.removeValue(forKey: key)
            } else {
                Self.trim(&usage)
                self.diskUsageGraph[key] = usage
            }
        }

        let id =
            self.usageGraph.last?.id.advanced(by: 1)
            ?? UInt64(Date().timeIntervalSince1970.magnitude)

        self.usageGraph.append(
            UsagePoint(
                id: id,
                eCPUUsage: metrics.getECPUInfo(),
                pCPUUsage: metrics.getPCPUInfo(),
                gpuUsage: [metrics.getGPUUsage(), metrics.getGPUFreq()],
                memUsage: [metrics.getMemUsage(), metrics.getMemUsed()],
                swapUsage: [metrics.getSwapUsage(), metrics.getSwapUsed()],
                networkUsage: metrics.networkUsage
            )
        )
        Self.trim(&self.usageGraph)

        for (key, drive) in disks {
            guard let usage = metrics.diskUsage[key] else {
                continue
            }

            let point = DiskUsagePoint(
                id: id,
                name: drive.mediaName,
                usage: usage
            )
            if var queue = self.diskUsageGraph[key] {
                queue.append(point)
                Self.trim(&queue)
                self.diskUsageGraph[key] = queue
            } else {
                var seeded = DiskUsagePoint.mockData(
                    sId: id - UInt64(GRAPH_POINTS_MAX)
                )
                seeded.append(point)
                Self.trim(&seeded)
                self.diskUsageGraph[key] = seeded
            }
        }

        NotificationManager.shared.evaluate(metrics: metrics)
    }

    private static func resolve(processes: [RawProcessUsage]) -> [ProcessUsage] {
        return processes.map { raw in
            let app = NSRunningApplication(processIdentifier: raw.responsiblePid)
            let bundleId = app?.bundleIdentifier

            return ProcessUsage(
                id: bundleId ?? "pid:\(raw.responsiblePid)",
                name: app?.localizedName ?? raw.command,
                icon: app?.icon,
                pids: raw.pids,
                cpuPercent: raw.cpuPercent,
                memoryBytes: raw.memoryBytes,
                diskBytesPerSec: raw.diskBytesPerSec,
                networkBytesPerSec: 0
            )
        }
    }

    private static func trim<T>(_ queue: inout Deque<T>) {
        while queue.count > GRAPH_POINTS_MAX {
            let _ = queue.popFirst()
        }
    }
}
