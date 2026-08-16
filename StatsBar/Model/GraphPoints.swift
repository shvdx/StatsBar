//
//  GraphPoints.swift
//  StatsBar
//
//  Created by Shashank on 25/11/24.
//

import Charts
import Collections
import Foundation

enum NetworkUsageType: String, Plottable {
    case upload = "upload"
    case download = "download"
}

enum DiskUsageType: String, Plottable {
    case read = "read"
    case write = "write"
}

struct DiskUsagePoint: Identifiable {
    let id: UInt64
    let name: String
    let usage: [(value: Int64, type: DiskUsageType)]

    init(id: UInt64, name: String, usage: (read: Int64, write: Int64)) {
        self.id = id
        self.name = name
        self.usage = [(usage.read, .read), (max(0, usage.write) * -1, .write)]
    }

    static func mockData(sId: UInt64? = nil) -> Deque<DiskUsagePoint> {
        var res: Deque<DiskUsagePoint> = []
        for _ in 0..<GRAPH_POINTS_MAX {
            res.append(
                DiskUsagePoint(
                    id: res.last?.id.advanced(by: 1) ?? sId ?? 1,
                    name: "",
                    usage: (0, 0)
                )
            )
        }
        return res
    }
}

struct UsagePoint: Identifiable {
    let id: UInt64
    let eCpuUsage: [Double]
    let pCpuUsage: [Double]
    let gpuUsage: [Double]
    let memUsage: [Double]
    let swapUsage: [Double]
    let networkUsage: [(value: Int64, type: NetworkUsageType)]

    init(
        id: UInt64,
        eCPUUsage: [Double],
        pCPUUsage: [Double],
        gpuUsage: [Double],
        memUsage: [Double],
        swapUsage: [Double],
        networkUsage: (upload: Int64, download: Int64)
    ) {
        self.id = id
        self.eCpuUsage = eCPUUsage
        self.pCpuUsage = pCPUUsage
        self.gpuUsage = gpuUsage
        self.memUsage = memUsage
        self.swapUsage = swapUsage
        self.networkUsage = [
            (networkUsage.upload * -1, .upload),
            (networkUsage.download, .download),
        ]
    }

    static func mockData() -> Deque<UsagePoint> {
        var res: Deque<UsagePoint> = []
        for _ in 0..<GRAPH_POINTS_MAX {
            res.append(
                UsagePoint(
                    id: res.last?.id.advanced(by: 1) ?? 1,
                    eCPUUsage: [0, 0],
                    pCPUUsage: [0, 0],
                    gpuUsage: [0, 0],
                    memUsage: [0, 0],
                    swapUsage: [0, 0],
                    networkUsage: (0, 0)
                )
            )
        }
        return res
    }
}
