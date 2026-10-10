//
//  CoreTier+Color.swift
//  StatsBar
//
//  Created by Shashank on 10/10/26.
//

import SwiftUI

extension CoreTier {
    // series color in CPU charts, legend, menu-bar glyph
    var color: Color {
        switch self {
        case .efficiency: return Color.blue
        case .performance: return Color.green
        case .superCore: return Color.teal
        }
    }
}
