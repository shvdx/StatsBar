//
//  MetricsEngine.swift
//  StatsBar
//
//  Created by Shashank on 16/08/25.
//

import Foundation
import Collections

@MainActor
@Observable
final class MetricsEngine {

    private(set) var metrics: Metrics?
    private(set) var disks: OrderedDictionary<String, Drive> = [:]
    private(set) var usageGraph: Deque<UsagePoint> = UsagePoint.mockData()
    private(set) var diskUsageGraph: OrderedDictionary<String, Deque<DiskUsagePoint>> = [:]
    private(set) var errorMessage: String = ""

    private var sampler: Sampler?
    private var task: Task<Void, Never>?

    // 500 ms idle + ~500 ms sampling window in getMetrics() => ~1 update/sec.
    private static let sample_interval_ms = 500

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
        assert(self.task == nil);
        assert(self.sampler == nil);

        let sampler: Sampler
        do {
            sampler = try Sampler()
        } catch {
            self.errorMessage = "\(error)"
            return
        }

        self.sampler = sampler
        self.errorMessage = ""

        // Sample off the main thread; hop back to apply/fail for state mutation.
        self.task = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(Self.sample_interval_ms), tolerance: .zero)
                    let metrics = try await sampler.getMetrics()
                    let disks = sampler.disk.getDisks()

                    if Task.isCancelled {
                        return
                    }
                    await self?.apply(metrics: metrics, disks: disks)
                } catch is CancellationError {
                    return
                } catch {
                    await self?.fail(error)
                    return
                }
            }
        }
    }

    func stop() {
        self.task?.cancel()
        self.task = nil
        self.sampler = nil
    }

    private func fail(_ error: Error) {
        self.errorMessage = "\(error)"
        self.stop()
    }

    private func apply(metrics: Metrics, disks: OrderedDictionary<String, Drive>) {
        assert(self.usageGraph.count <= GRAPH_POINTS_MAX);

        self.disks = disks
        self.metrics = metrics

        // Drop graphs for disks that went away; trim the survivors.
        for (key, var usage) in self.diskUsageGraph {
            if disks[key] == nil {
                self.diskUsageGraph.removeValue(forKey: key)
            } else {
                Self.trim(&usage)
                self.diskUsageGraph[key] = usage
            }
        }

        let id = self.usageGraph.last?.id.advanced(by: 1)
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

            let point = DiskUsagePoint(id: id, name: drive.mediaName, usage: usage)
            if var queue = self.diskUsageGraph[key] {
                queue.append(point)
                Self.trim(&queue)
                self.diskUsageGraph[key] = queue
            } else {
                var seeded = DiskUsagePoint.mockData(sId: id - UInt64(GRAPH_POINTS_MAX))
                seeded.append(point)
                Self.trim(&seeded)
                self.diskUsageGraph[key] = seeded
            }
        }

        NotificationManager.shared.evaluate(metrics: metrics)
    }

    private static func trim<T>(_ queue: inout Deque<T>) {
        while queue.count > GRAPH_POINTS_MAX {
            let _ = queue.popFirst()
        }
    }
}
