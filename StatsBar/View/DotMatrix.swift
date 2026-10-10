//
//  DotMatrix.swift
//  StatsBar
//
//  Created by Shashank on 10/10/26.
//

import Charts
import SwiftUI

// grid spacing; uniform across charts, independent of sample count
private let DOT_PITCH: CGFloat = 4.5
private let DOT_DIAMETER: CGFloat = 3
private let DOT_CORNER_RADIUS: CGFloat = 1

// 800pt popover / 4.5 => far below; bounds the per-frame loop
private let DOT_COLUMNS_MAX = 256
private let DOT_ROWS_MAX = 256

struct DotSeries<Value: Plottable & Numeric> {
    let color: Color
    let points: [(x: UInt64, y: Value)]
}

struct DotMatrix<Value: Plottable & Numeric>: View {
    let proxy: ChartProxy
    let series: [DotSeries<Value>]
    var cornerRadius: CGFloat = CORNER_RADIUS

    var body: some View {
        GeometryReader { geometry in
            if let plotFrame = self.proxy.plotFrame {
                let plot = geometry[plotFrame]
                let bounds = CGRect(origin: .zero, size: geometry.size)

                Canvas { context, _ in
                    for item in self.series {
                        context.fill(
                            Self.dots(
                                proxy: self.proxy,
                                points: item.points,
                                plot: plot,
                                bounds: bounds,
                                cornerRadius: self.cornerRadius
                            ),
                            with: .color(item.color)
                        )
                    }
                }
            }
        }
    }

    private static func dots(
        proxy: ChartProxy,
        points: [(x: UInt64, y: Value)],
        plot: CGRect,
        bounds: CGRect,
        cornerRadius: CGFloat
    ) -> Path {
        assert(points.count <= GRAPH_POINTS_MAX)
        var path = Path()
        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return path
        }

        guard let x_first = proxy.position(forX: first.x),
            let x_last = proxy.position(forX: last.x),
            let baseline = proxy.position(forY: Value.zero)
        else { return path }

        // all-zero => nothing to draw
        guard baseline.isFinite, x_last > x_first else { return path }

        assert(DOT_DIAMETER < DOT_PITCH)

        let reach = DOT_DIAMETER / 2 * 2.squareRoot()
        let columns = Self.grid(length: plot.width, count_max: DOT_COLUMNS_MAX)
        let rows = Self.grid(length: plot.height, count_max: DOT_ROWS_MAX)

        let rows_up = rows.filter { $0 < baseline }.reversed()
        let rows_down = rows.filter { $0 > baseline }

        for column in columns {
            // nearest sample to this column; samples are evenly spaced
            let fraction = (column - x_first) / (x_last - x_first)
            let index = min(
                max(0, Int((fraction * CGFloat(points.count - 1)).rounded())),
                points.count - 1
            )

            guard let y = proxy.position(forY: points[index].y), y.isFinite else { continue }
            let height = baseline - y  // > 0 => above baseline
            guard abs(height) > 0 else { continue }

            // any nonzero value lights >= 1 dot
            let lit = max(1, Int((abs(height) / DOT_PITCH).rounded()))
            let side = height > 0 ? Array(rows_up) : rows_down
            for row in side.prefix(lit) {
                let center = CGPoint(x: plot.minX + column, y: plot.minY + row)
                guard
                    Self.inside(
                        center: center,
                        radius: reach,
                        bounds: bounds,
                        cornerRadius: cornerRadius
                    )
                else { continue }

                let origin = CGPoint(
                    x: ((center.x - DOT_DIAMETER / 2) * 2).rounded() / 2,
                    y: ((center.y - DOT_DIAMETER / 2) * 2).rounded() / 2
                )
                path.addRoundedRect(
                    in: CGRect(
                        origin: origin,
                        size: CGSize(width: DOT_DIAMETER, height: DOT_DIAMETER)
                    ),
                    cornerSize: CGSize(width: DOT_CORNER_RADIUS, height: DOT_CORNER_RADIUS)
                )
            }
        }
        return path
    }

    // dot centers along `length`, centered; edge margin >= gap between dots
    private static func grid(length: CGFloat, count_max: Int) -> [CGFloat] {
        let gap = DOT_PITCH - DOT_DIAMETER
        let count = min(max(0, Int((length - gap) / DOT_PITCH)), count_max)

        let start = (length - CGFloat(count) * DOT_PITCH) / 2 + DOT_PITCH / 2
        return (0..<count).map { start + CGFloat($0) * DOT_PITCH }
    }

    // dot fully within the rounded clip; corner dots that would be cut => skipped
    private static func inside(
        center: CGPoint,
        radius: CGFloat,
        bounds: CGRect,
        cornerRadius: CGFloat
    ) -> Bool {
        let nearest = CGPoint(
            x: min(max(center.x, bounds.minX + cornerRadius), bounds.maxX - cornerRadius),
            y: min(max(center.y, bounds.minY + cornerRadius), bounds.maxY - cornerRadius)
        )
        let distance = hypot(center.x - nearest.x, center.y - nearest.y)
        return distance <= cornerRadius - radius
    }
}
