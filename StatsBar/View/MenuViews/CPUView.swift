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

    @State private var cpuSelection: [CoreTier: UInt64?] = [:]
    @State private var gpuSelection: UInt64? = nil

    private var graphShape = RoundedRectangle(cornerRadius: CORNER_RADIUS)

    // e.g. "6E + 5P + 14GPU"; lowest tier first
    private var coresTitle: String {
        let tiers = (self.socInfo?.clusters ?? []).map { "\($0.cores)\($0.tier.short)" }
        return (tiers + ["\(self.socInfo?.gpuCores ?? 0)GPU"]).joined(separator: " + ")
    }

    private func binding(tier: CoreTier) -> Binding<UInt64?> {
        return .init(
            get: { self.cpuSelection[tier, default: nil] },
            set: { self.cpuSelection[tier] = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            ProcessMenu(
                title: "\(self.socInfo?.chipName ?? "") (\(self.coresTitle))",
                processes: self.processes,
                metric: .cpu
            )

            HStack(spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(Array(self.metrics.clusters.enumerated()), id: \.offset) {
                        index,
                        cluster in
                        if index > 0 {
                            Spacer()
                        }
                        self.usageChart(
                            color: cluster.tier.color,
                            selection: self.binding(tier: cluster.tier),
                            values: { $0.cpu(index) }
                        )
                    }
                }

                Spacer()

                self.usageChart(
                    color: Color.orange,
                    selection: $gpuSelection,
                    values: { $0.gpuUsage }
                )
            }
            .frame(height: 124)
            .padding(.vertical, 2)

            ForEach(Array(self.metrics.clusters.enumerated()), id: \.offset) { index, cluster in
                self.legendRow(
                    color: cluster.tier.color,
                    label: cluster.tier.label,
                    values: self.metrics.getClusterInfo(index)
                )
            }

            self.legendRow(
                color: Color.orange,
                label: "GPU",
                values: [self.metrics.getGPUUsage(), self.metrics.getGPUFreq()]
            )
        }
    }

    // dot-matrix usage chart; `values` => [usage %, freq GHz]
    private func usageChart(
        color: Color,
        selection: Binding<UInt64?>,
        values: @escaping (UsagePoint) -> [Double]
    ) -> some View {
        Chart(self.usageGraph) {
            AreaMark(
                x: .value("X", $0.id),
                y: .value("Y", values($0)[0])
            )
            .opacity(0)  // keeps scale + selection; DotMatrix draws the fill
            .foregroundStyle(color)

            if let selected = selection.wrappedValue {
                RuleMark(x: .value("X", selected))
                    .foregroundStyle(color)
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit, y: .fit)
                    ) {
                        ZStack {
                            if let usage = (self.usageGraph.first { $0.id == selected }) {
                                Text(
                                    String(
                                        format: "%.2f%%  %.2f GHz",
                                        arguments: values(usage)
                                    )
                                )
                                .font(.jb(.callout))
                                .foregroundStyle(color.adaptedTextColor(self.environment))
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(color, in: RoundedRectangle(cornerRadius: CORNER_RADIUS))
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
        .chartXSelection(value: selection)
        .chartBackground { proxy in
            DotMatrix(
                proxy: proxy,
                series: [
                    DotSeries(color: color, points: self.usageGraph.map { ($0.id, values($0)[0]) })
                ]
            )
        }
        .clipShape(self.graphShape)
        .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
    }

    // `values` => [usage %, freq GHz]
    private func legendRow(color: Color, label: String, values: [Double]) -> some View {
        HStack(alignment: .center) {
            Circle()
                .foregroundStyle(color)
                .frame(width: 10, height: 10, alignment: .center)
            Text(label)
                .font(.jb(.callout))
            Spacer()
            Text(String(format: "%.2f%%  %.2f GHz", arguments: values))
                .font(.jb(.callout))
        }
        .padding(.vertical, 2)
    }
}
