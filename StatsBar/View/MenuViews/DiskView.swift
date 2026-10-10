//
//  DiskView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import Charts
import Collections
import SwiftUI

struct DiskView: View {
    @Environment(\.self) var environment

    var metrics: Metrics
    let disks: OrderedDictionary<String, Drive>
    let diskUsageGraph: OrderedDictionary<String, Deque<DiskUsagePoint>>

    init(
        metrics: Metrics,
        disks: OrderedDictionary<String, Drive>,
        diskUsageGraph: OrderedDictionary<String, Deque<DiskUsagePoint>>
    ) {
        self.metrics = metrics
        self.disks = disks
        self.diskUsageGraph = diskUsageGraph
    }

    @State private var diskSelection: [String: UInt64?] = [:]

    private var graphShape = RoundedRectangle(cornerRadius: CORNER_RADIUS)

    private func getDiskGraphDomain(disk: String) -> [Int64] {
        let maxUsage = (self.diskUsageGraph[disk] ?? []).reduce(Int64(0)) {
            max($0, max(abs($1.usage[0].value), abs($1.usage[1].value)))
        }
        return [maxUsage * -1, maxUsage]
    }

    private func binding(disk: String) -> Binding<UInt64?> {
        return .init(
            get: { self.diskSelection[disk, default: nil] },
            set: { self.diskSelection[disk] = $0 }
        )
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(
                Array(self.diskUsageGraph.elements.enumerated()),
                id: \.offset
            ) { index, element in
                VStack(spacing: 8) {
                    HStack(alignment: .center) {
                        Text(
                            "Disk: \(self.disks[element.key]?.mediaName ?? "")"
                        )
                        .font(.jb(.callout))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()

                        Text(
                            "\(element.key) (\(self.disks[element.key]?.fileSystem.uppercased() ?? ""))"
                        )
                        .font(.jb(size: 12))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Chart {
                        ForEach(element.value, id: \.id) { usageInfo in
                            ForEach(usageInfo.usage, id: \.type) { diskUsage in
                                AreaMark(
                                    x: .value("X", usageInfo.id),
                                    y: .value("Y", diskUsage.value)
                                )
                                .opacity(0)  // keeps scale + selection; DotMatrix draws the fill
                                .foregroundStyle(
                                    by: .value("OP Bytes type", diskUsage.type)
                                )
                            }
                        }

                        if let selection = self.diskSelection[element.key],
                            let selection
                        {
                            if let usage =
                                (self.diskUsageGraph[element.key]?.first {
                                    $0.id == selection
                                })
                            {
                                RuleMark(x: .value("X", selection), yStart: 0)
                                    .foregroundStyle(
                                        LinearGradient(
                                            stops: [
                                                Gradient.Stop(
                                                    color: .mint,
                                                    location: 0.0
                                                ),
                                                Gradient.Stop(
                                                    color: .mint,
                                                    location: 0.5
                                                ),
                                                Gradient.Stop(
                                                    color: .blue,
                                                    location: 0.50001
                                                ),
                                                Gradient.Stop(
                                                    color: .blue,
                                                    location: 1.0
                                                ),
                                            ],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .annotation(
                                        position: .top,
                                        overflowResolution: .init(
                                            x: .fit,
                                            y: .fit
                                        )
                                    ) {
                                        ZStack {
                                            Text(
                                                Units(
                                                    bytes: usage.usage[0].value
                                                ).getReadableString()
                                            )
                                            .font(.jb(.callout))
                                            .foregroundStyle(
                                                Color.blue.adaptedTextColor(
                                                    self.environment
                                                )
                                            )
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                        .background(
                                            Color.blue,
                                            in: RoundedRectangle(cornerRadius: CORNER_RADIUS)
                                        )
                                        .drawingGroup()
                                    }
                                    .annotation(
                                        position: .bottom,
                                        overflowResolution: .init(
                                            x: .fit,
                                            y: .fit
                                        )
                                    ) {
                                        ZStack {
                                            Text(
                                                Units(
                                                    bytes: abs(
                                                        usage.usage[1].value
                                                    )
                                                ).getReadableString()
                                            )
                                            .font(.jb(.callout))
                                            .foregroundStyle(
                                                Color.mint.adaptedTextColor(
                                                    self.environment
                                                )
                                            )
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                        .background(
                                            Color.mint,
                                            in: RoundedRectangle(cornerRadius: CORNER_RADIUS)
                                        )
                                        .drawingGroup()
                                    }
                            }
                        }
                    }
                    .chartLegend(.hidden)
                    .chartForegroundStyleScale([
                        DiskUsageType.read: Color.blue,
                        DiskUsageType.write: Color.mint,
                    ])
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: [
                        self.diskUsageGraph[element.key]?.first?.id ?? 0,
                        self.diskUsageGraph[element.key]?.last?.id ?? 0,
                    ])
                    .chartYScale(domain: getDiskGraphDomain(disk: element.key))
                    .chartXSelection(value: self.binding(disk: element.key))
                    .chartBackground { proxy in
                        DotMatrix(
                            proxy: proxy,
                            series: [
                                DotSeries(
                                    color: Color.blue,
                                    points: element.value.map { ($0.id, $0.usage[0].value) }
                                ),
                                DotSeries(
                                    color: Color.mint,
                                    points: element.value.map { ($0.id, $0.usage[1].value) }
                                ),
                            ]
                        )
                    }
                    .clipShape(self.graphShape)
                    .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
                    .frame(height: 124)
                    .padding(.vertical, 2)

                    HStack(alignment: .center) {
                        HStack(alignment: .center) {
                            Circle().foregroundStyle(Color.blue).frame(
                                width: 10,
                                height: 10,
                                alignment: .center
                            )
                            Text("Read")
                                .font(.jb(.callout))
                            Spacer()
                            Text(
                                Units(
                                    bytes: metrics.getDiskRead(key: element.key)
                                ).getReadableString()
                            )
                            .font(.jb(.callout))
                        }

                        Divider()
                            .padding(.vertical, 6)
                            .padding(.horizontal, 6)

                        HStack(alignment: .center) {
                            Circle()
                                .foregroundStyle(Color.mint)
                                .frame(width: 10, height: 10, alignment: .center)
                            Text("Write")
                                .font(.jb(.callout))
                            Spacer()
                            Text(
                                Units(
                                    bytes: metrics.getDiskWrite(
                                        key: element.key
                                    )
                                ).getReadableString()
                            )
                            .font(.jb(.callout))
                        }
                    }
                    .padding(.vertical, 2)

                    if let disk = self.disks[element.key] {
                        HStack(alignment: .center) {
                            Text("Available")
                                .font(.jb(.callout))
                            Spacer()
                            Text(
                                "\(DiskSize(size: self.disks[element.key]?.free ?? 0).getReadableMemory()) / \(DiskSize(size: self.disks[element.key]?.size ?? 0).getReadableMemory())"
                            )
                            .font(.jb(.callout))
                        }
                        .padding(.vertical, 2)

                        if !disk.root {
                            HStack(alignment: .center) {
                                Text("Connection")
                                    .font(.jb(.callout))
                                Spacer()
                                Text(
                                    self.disks[element.key]?.connectionType
                                        .uppercased() ?? "--"
                                )
                                .font(.jb(.callout))
                            }
                            .padding(.vertical, 2)

                            HStack(alignment: .center) {
                                Text("Model")
                                    .font(.jb(.callout))
                                Spacer()
                                Text(
                                    self.disks[element.key]?.model.uppercased()
                                        ?? "--"
                                )
                                .font(.jb(.callout))
                            }
                            .padding(.vertical, 2)
                        }
                    }

                }

                if index != (self.disks.count - 1) {
                    Divider().padding(6)
                }
            }
        }
    }
}
