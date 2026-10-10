//
//  NetworkView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import AppKit
import Charts
import Collections
import SwiftUI

struct NetworkView: View {
    @Environment(\.self) var environment

    let network: Network?
    var metrics: Metrics
    let usageGraph: Deque<UsagePoint>

    init(network: Network?, metrics: Metrics, usageGraph: Deque<UsagePoint>) {
        self.network = network
        self.metrics = metrics
        self.usageGraph = usageGraph
    }

    @State private var networkSelection: UInt64? = nil

    private var graphShape = RoundedRectangle(cornerRadius: CORNER_RADIUS)

    // Wi-Fi connected but no SSID and location not granted => name is hidden.
    private var showLocationWarning: Bool {
        guard self.network?.getConnType() == .wifi else { return false }
        guard (self.network?.getSSID() ?? "").isEmpty else { return false }
        return !LocationAuth.shared.isAuthorized
    }

    private func openLocationSettings() {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func getNetworkGraphDomain() -> [Int64] {
        let maxUsage = self.usageGraph.reduce(Int64(0)) {
            max(
                $0,
                max(
                    abs($1.networkUsage[0].value),
                    abs($1.networkUsage[1].value)
                )
            )
        }
        return [maxUsage * -1, maxUsage]
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Text("Network: \(network?.getSSID() ?? "")")
                        .font(.jb(.callout))
                        .fontWeight(.semibold)

                    if self.showLocationWarning {
                        Button {
                            self.openLocationSettings()
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.jb(.caption))
                        }
                        .buttonStyle(.plain)
                        .help(
                            "Grant Location access to show the Wi-Fi network name."
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text(
                    "\(network?.getBSDName() ?? "") (\(network?.getInterfaceName() ?? ""))"
                )
                .font(.jb(size: 12))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Chart {
                ForEach(self.usageGraph, id: \.id) { usageInfo in
                    ForEach(usageInfo.networkUsage, id: \.type) {
                        networkUsage in
                        AreaMark(
                            x: .value("X", usageInfo.id),
                            y: .value("Y", networkUsage.value)
                        )
                        .opacity(0)  // keeps scale + selection; DotMatrix draws the fill
                        .foregroundStyle(
                            by: .value("Bytes type", networkUsage.type)
                        )
                    }
                }

                if let networkSelection {
                    if let usage =
                        (self.usageGraph.first { $0.id == networkSelection })
                    {
                        RuleMark(x: .value("X", networkSelection), yStart: 0)
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(
                                            color: .purple,
                                            location: 0.0
                                        ),
                                        Gradient.Stop(
                                            color: .purple,
                                            location: 0.5
                                        ),
                                        Gradient.Stop(
                                            color: .indigo,
                                            location: 0.50001
                                        ),
                                        Gradient.Stop(
                                            color: .indigo,
                                            location: 1.0
                                        ),
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .annotation(
                                position: .top,
                                overflowResolution: .init(x: .fit, y: .fit)
                            ) {
                                ZStack {
                                    Text(
                                        Units(
                                            bytes: usage.networkUsage[1].value
                                        ).getReadableString()
                                    )
                                    .font(.jb(.callout))
                                    .foregroundStyle(
                                        Color.indigo.adaptedTextColor(
                                            self.environment
                                        )
                                    )
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(
                                    Color.indigo,
                                    in: RoundedRectangle(cornerRadius: CORNER_RADIUS)
                                )
                                .drawingGroup()
                            }
                            .annotation(
                                position: .bottom,
                                overflowResolution: .init(x: .fit, y: .fit)
                            ) {
                                ZStack {
                                    Text(
                                        Units(
                                            bytes: abs(
                                                usage.networkUsage[0].value
                                            )
                                        ).getReadableString()
                                    )
                                    .font(.jb(.callout))
                                    .foregroundStyle(
                                        Color.purple.adaptedTextColor(
                                            self.environment
                                        )
                                    )
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(
                                    Color.purple,
                                    in: RoundedRectangle(cornerRadius: CORNER_RADIUS)
                                )
                                .drawingGroup()
                            }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartForegroundStyleScale([
                NetworkUsageType.download: Color.indigo,
                NetworkUsageType.upload: Color.purple,
            ])
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: [
                self.usageGraph.first?.id ?? 0, self.usageGraph.last?.id ?? 0,
            ])
            .chartYScale(domain: getNetworkGraphDomain())
            .chartXSelection(value: $networkSelection)
            .chartBackground { proxy in
                DotMatrix(
                    proxy: proxy,
                    series: [
                        DotSeries(
                            color: Color.indigo,
                            points: self.usageGraph.map { ($0.id, $0.networkUsage[1].value) }
                        ),
                        DotSeries(
                            color: Color.purple,
                            points: self.usageGraph.map { ($0.id, $0.networkUsage[0].value) }
                        ),
                    ]
                )
            }
            .clipShape(self.graphShape)
            .overlay(self.graphShape.stroke(.gray, lineWidth: 1))
            .frame(height: 124)
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                Circle()
                    .foregroundStyle(Color.indigo).frame(
                        width: 10,
                        height: 10,
                        alignment: .center
                    )
                Text("Download")
                    .font(.jb(.callout))
                Spacer()
                Text(
                    Units(bytes: metrics.networkUsage.download)
                        .getReadableString()
                )
                .font(.jb(.callout))
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                Circle()
                    .foregroundStyle(Color.purple)
                    .frame(width: 10, height: 10, alignment: .center)
                Text("Upload")
                    .font(.jb(.callout))
                Spacer()
                Text(
                    Units(bytes: metrics.networkUsage.upload)
                        .getReadableString()
                )
                .font(.jb(.callout))
            }
            .padding(.vertical, 2)

            HStack(alignment: .center) {
                Image(
                    systemName: (network?.getConnType() ?? .other)
                        .getSystemIcon()
                )
                .frame(width: 8, height: 8, alignment: .center)
                .padding(.leading, 2)
                Text("Local IP")
                    .font(.jb(.callout))
                Spacer()
                Text(network?.getLocalIP() ?? "--")
                    .font(.jb(.callout))
            }
            .padding(.vertical, 2)
        }
    }
}
