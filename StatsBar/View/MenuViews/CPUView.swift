//
//  CPUView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import Charts
import Collections
import SwiftUI

struct CPUView: View {
    @Environment(\.self) var environment

    let socInfo: SOCInfo?
    var metrics: Metrics
    let usageGraph: Deque<UsagePoint>
    let processes: [ProcessUsage]

    init(
        socInfo: SOCInfo?,
        metrics: Metrics,
        usageGraph: Deque<UsagePoint>,
        processes: [ProcessUsage]
    ) {
        self.socInfo = socInfo
        self.metrics = metrics
        self.usageGraph = usageGraph
        self.processes = processes
    }

    @State private var eCpuSelection: UInt64? = nil
    @State private var pCpuSelection: UInt64? = nil
    @State private var gpuSelection: UInt64? = nil

    private var graphShape = RoundedRectangle(cornerRadius: 12)

    var body: some View {
        VStack(spacing: 8) {
            ProcessMenu(
                title:
                    "\(self.socInfo?.chipName ?? "") (\(self.socInfo?.eCores ?? 0)E + \(self.socInfo?.pCores ?? 0)P + \(self.socInfo?.gpuCores ?? 0)GPU)",
                processes: self.processes,
                metric: .cpu
            )

            HStack(spacing: 4) {
                VStack(spacing: 4) {
                    Chart(self.usageGraph) {
                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.eCpuUsage[0])
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.blue)

                        if let eCpuSelection {
                            RuleMark(x: .value("X", eCpuSelection))
                                .foregroundStyle(Color.blue)
                                .annotation(
                                    position: .top,
                                    overflowResolution: .init(x: .fit, y: .fit)
                                ) {
                                    ZStack {
                                        if let usage =
                                            (self.usageGraph.first {
                                                $0.id == eCpuSelection
                                            })
                                        {
                                            Text(
                                                String(
                                                    format: "%.2f%%  %.2f GHz",
                                                    arguments: usage.eCpuUsage
                                                )
                                            )
                                            .font(.jb(.callout))
                                            .foregroundStyle(
                                                Color.blue.adaptedTextColor(
                                                    self.environment
                                                )
                                            )
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                                    .drawingGroup()
                                }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: [
                        self.usageGraph.first?.id ?? 0,
                        self.usageGraph.last?.id ?? 0,
                    ])
                    .chartYScale(domain: [0, 100])
                    .chartXSelection(value: $eCpuSelection)
                    .clipShape(self.graphShape)
                    .overlay(self.graphShape.stroke(.gray, lineWidth: 1))

                    Spacer()

                    Chart(self.usageGraph) {
                        AreaMark(
                            x: .value("X", $0.id),
                            y: .value("Y", $0.pCpuUsage[0])
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.green)

                        if let pCpuSelection {
                            RuleMark(x: .value("X", pCpuSelection))
                                .foregroundStyle(Color.green)
                                .annotation(
                                    position: .top,
                                    overflowResolution: .init(x: .fit, y: .fit)
                                ) {
                                    ZStack {
                                        if let usage =
                                            (self.usageGraph.first {
                                                $0.id == pCpuSelection
                                            })
                                        {
                                            Text(
                                                String(
                                                    format: "%.2f%%  %.2f GHz",
                                                    arguments: usage.pCpuUsage
                                                )
                                            )
                                            .font(.jb(.callout))
                                            .foregroundStyle(
                                                Color.green.adaptedTextColor(
                                                    self.environment
                                                )
                                            )
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(Color.green, in: RoundedRectangle(cornerRadius: 10))
                                    .drawingGroup()
                                }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: [
                        self.usageGraph.first?.id ?? 0,
                        self.usageGraph.last?.id ?? 0,
                    ])
                    .chartYScale(domain: [0, 100])
                    .chartXSelection(value: $pCpuSelection)
                    .clipShape(self.graphShape)
                    .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
                }

                Spacer()

                Chart(self.usageGraph) {
                    AreaMark(
                        x: .value("X", $0.id),
                        y: .value("Y", $0.gpuUsage[0])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.orange)

                    if let gpuSelection {
                        RuleMark(x: .value("X", gpuSelection))
                            .foregroundStyle(Color.orange)
                            .annotation(
                                position: .top,
                                overflowResolution: .init(x: .fit, y: .fit)
                            ) {
                                ZStack {
                                    if let usage =
                                        (self.usageGraph.first {
                                            $0.id == gpuSelection
                                        })
                                    {
                                        Text(
                                            String(
                                                format: "%.2f%%  %.2f GHz",
                                                arguments: usage.gpuUsage
                                            )
                                        )
                                        .font(.jb(.callout))
                                        .foregroundStyle(
                                            Color.orange.adaptedTextColor(
                                                self.environment
                                            )
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                                .drawingGroup()
                            }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXScale(domain: [
                    self.usageGraph.first?.id ?? 0,
                    self.usageGraph.last?.id ?? 0,
                ])
                .chartYScale(domain: [0, 100])
                .chartXSelection(value: $gpuSelection)
                .clipShape(self.graphShape)
                .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
            }
            .frame(height: 124)
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.blue)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("E-CPU")
                    .font(.jb(.callout))
                Spacer()
                Text(
                    String(
                        format: "%.2f%%  %.2f GHz",
                        arguments: metrics.getECPUInfo()
                    )
                )
                .font(.jb(.callout))
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.green)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("P-CPU")
                    .font(.jb(.callout))
                Spacer()
                Text(
                    String(
                        format: "%.2f%%  %.2f GHz",
                        arguments: metrics.getPCPUInfo()
                    )
                )
                .font(.jb(.callout))
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.orange)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("GPU")
                    .font(.jb(.callout))
                Spacer()
                Text(
                    String(
                        format: "%.2f%%  %.2f GHz",
                        arguments: [
                            metrics.getGPUUsage(), metrics.getGPUFreq(),
                        ]
                    )
                )
                .font(.jb(.callout))
            }
            .padding(.vertical, 2)
        }
    }
}
