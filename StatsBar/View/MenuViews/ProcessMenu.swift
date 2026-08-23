//
//  ProcessMenu.swift
//  StatsBar
//
//  Created by Shashank on 23/08/26.
//

import SwiftUI

enum ProcessMetric {
    case cpu
    case memory
    case disk
}

struct ProcessMenu: View {

    let title: String
    let processes: [ProcessUsage]
    let metric: ProcessMetric

    @State private var expanded = false

    private static let top_n = 5

    var body: some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.expanded.toggle()
                }
            } label: {
                HStack {
                    Text(self.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.caption)
                    Image(systemName: self.expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if self.expanded {
                VStack(spacing: 4) {
                    ForEach(self.ranked()) { process in
                        self.row(process)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ranked() -> [ProcessUsage] {
        let sorted = self.processes.sorted { lhs, rhs in
            switch self.metric {
            case .cpu:
                return lhs.cpuPercent > rhs.cpuPercent
            case .memory:
                return lhs.memoryBytes > rhs.memoryBytes
            case .disk:
                return lhs.diskBytesPerSec > rhs.diskBytesPerSec
            }
        }
        return Array(sorted.prefix(Self.top_n))
    }

    private func row(_ process: ProcessUsage) -> some View {
        HStack(spacing: 8) {
            self.icon(process)
                .resizable()
                .frame(width: 16, height: 16)
            Text(process.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(self.value(process))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func icon(_ process: ProcessUsage) -> Image {
        if let nsImage = process.icon {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "gearshape")
    }

    private func value(_ process: ProcessUsage) -> String {
        switch self.metric {
        case .cpu:
            return String(format: "%.1f%%", process.cpuPercent)
        case .memory:
            return Units(bytes: Int64(process.memoryBytes)).getReadableString().replacing(
                "/s",
                with: ""
            )
        case .disk:
            return Units(bytes: Int64(process.diskBytesPerSec))
                .getReadableString() + "/s"
        }
    }
}
