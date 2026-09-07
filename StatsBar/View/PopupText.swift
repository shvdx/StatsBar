//
//  PopupText.swift
//  StatsBar
//
//  Created by Shashank on 25/11/24.
//

import SwiftUI

struct PopupText: View {

    var engine: MetricsEngine

    var body: some View {
        HStack {
            if case .failed = self.engine.status {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("StatsBar")
                }
            } else if let metric = self.engine.metrics {
                HStack(spacing: 8) {
                    //                    Image(systemName: "cpu")
                    //                        .font(.jb(size: 15))
                    //                    VStack {
                    //                        Text("CPU").font(.jb(size: 8))
                    //                        //                        Text(String(format: "%.2f / %.2f GHz", arguments: metric.getCPUFreqs()))
                    //                        //                            .font(.jb(.footnote))
                    //                        Text(String(format: "%.1f%%", arguments: [metric.getCPUUsage()]))
                    //                            .font(.jb(size: 11))
                    //                    }

                    VStack(alignment: .center) {
                        Text("C").font(.jb(size: 8)).offset(x: 0.0, y: 2)
                        Text("P").font(.jb(size: 8))
                        Text("U").font(.jb(size: 8)).offset(x: 0.0, y: -2.5)
                    }
                    .frame(height: POPUP_VIEW_HEIGHT)

                    ZStack {
                        HStack(spacing: 1) {
                            ForEach(
                                Array(metric.eCores.enumerated()),
                                id: \.offset
                            ) { index, v in
                                VStack {
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 2,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 2,
                                        style: .circular
                                    )
                                    .foregroundStyle(Color.blue)
                                    .frame(
                                        width: 56
                                            / CGFloat(
                                                metric.eCores.count
                                                    + metric.pCores.count
                                            ),
                                        height: POPUP_VIEW_HEIGHT * CGFloat(v),
                                        alignment: .bottom
                                    )
                                }
                                .frame(
                                    height: POPUP_VIEW_HEIGHT,
                                    alignment: .bottom
                                )
                            }
                            ForEach(
                                Array(metric.pCores.enumerated()),
                                id: \.offset
                            ) { index, v in
                                VStack {
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 2,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 2,
                                        style: .circular
                                    )
                                    .foregroundStyle(Color.green)
                                    .frame(
                                        width: 56
                                            / CGFloat(
                                                metric.eCores.count
                                                    + metric.pCores.count
                                            ),
                                        height: POPUP_VIEW_HEIGHT * CGFloat(v),
                                        alignment: .bottom
                                    )
                                }
                                .frame(
                                    height: POPUP_VIEW_HEIGHT,
                                    alignment: .bottom
                                )
                            }
                        }
                        .padding(.horizontal, 1)
                        .frame(maxWidth: 68)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 3).stroke(lineWidth: 0.5)
                    )

                    //                    Image(systemName: "cpu.fill")
                    //                        .font(.jb(size: 15))
                    //                    VStack {
                    //                        Text("GPU").font(.jb(size: 8))
                    //                        Text(String(format: "%.1f%%", arguments: [metric.getGPUUsage()]))
                    //                            .font(.jb(size: 11))
                    //                        //                        Text(String(format: "%.2f GHz", arguments: [metric.getGPUFreq()]))
                    //                        //                            .font(.jb(.footnote))
                    //                    }

                    VStack {
                        Text("G").font(.jb(size: 8)).offset(x: 0.0, y: 2)
                        Text("P").font(.jb(size: 8))
                        Text("U").font(.jb(size: 8)).offset(x: 0.0, y: -2.5)
                    }
                    .frame(height: POPUP_VIEW_HEIGHT)

                    ZStack {
                        VStack {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 2,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 2,
                                style: .circular
                            )
                            .foregroundStyle(Color.orange)
                            .frame(
                                width: 6,
                                height: POPUP_VIEW_HEIGHT
                                    * (CGFloat(metric.getGPUUsage()) / 100.0),
                                alignment: .bottom
                            )
                        }
                        .frame(height: POPUP_VIEW_HEIGHT, alignment: .bottom)
                        .padding(.horizontal, 1)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 3).stroke(lineWidth: 0.5)
                    )

                    //                    Text(" | ")
                    //                    Image(systemName: "memorychip")
                    //                        .font(.jb(size: 10))

                    VStack {
                        Text("MEM").font(.jb(size: 8))
                        Text(
                            String(
                                format: "%.1f GB",
                                arguments: [metric.getMemUsed()]
                            )
                        )
                        .font(.jb(size: 11))
                        //                        Text(String(format: "%.2f GHz", arguments: [metric.getGPUFreq()]))
                        //                            .font(.jb(.footnote))
                    }

                    HStack(spacing: 2) {
                        VStack(spacing: 5) {
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.jb(size: 7))
                                .opacity(
                                    metric.networkUsage.upload > 0
                                        ? .infinity : 0
                                )

                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.jb(size: 7))
                                .opacity(
                                    metric.networkUsage.download > 0
                                        ? .infinity : 0
                                )
                        }
                        VStack {
                            Text(
                                Units(bytes: metric.networkUsage.upload)
                                    .getReadableString()
                            )
                            .font(.jb(size: 9))
                            Text(
                                Units(bytes: metric.networkUsage.download)
                                    .getReadableString()
                            )
                            .font(.jb(size: 9))
                        }
                        //                        Text(String(format: "%.1f GB", arguments: [metric.getMemUsed()]))
                        //                            .font(.jb(size: 11))
                        //                        Text(String(format: "%.2f GHz", arguments: [metric.getGPUFreq()]))
                        //                            .font(.jb(.footnote))
                    }
                }
            } else {
                Text("StatsBar")
            }
        }
    }
}
