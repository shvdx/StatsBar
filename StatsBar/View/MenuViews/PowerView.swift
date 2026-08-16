//
//  PowerView.swift
//  StatsBar
//
//  Created by Shashank Verma on 09/07/25.
//

import SwiftUI

struct PowerView: View {

    var metrics: Metrics

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center) {
                self.cell("Power", watts: metrics.sysPower, bold: true)
                Divider()
                self.cell("CPU", watts: metrics.cpuPower / 1000.0)
            }

            Divider()

            HStack(alignment: .center) {
                self.cell("GPU", watts: metrics.gpuPower / 1000.0)
                Divider()
                self.cell("ANE", watts: metrics.anePower / 1000.0)
            }
        }
    }

    private func cell(_ title: String, watts: Float32, bold: Bool = false)
        -> some View
    {
        HStack {
            Text(title)
                .font(.callout)
                .fontWeight(bold ? .semibold : .regular)
            Spacer()
            Text(String(format: "%.2f W", arguments: [watts]))
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
    }
}
