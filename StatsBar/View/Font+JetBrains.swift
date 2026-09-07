//
//  Font+JetBrains.swift
//  StatsBar
//
//  Created by Shashank on 07/09/26.
//

import AppKit
import SwiftUI

extension Font {

    // JetBrains Mono, sized to match the platform text style so swapping the
    // family in doesn't change layout; scales with Dynamic Type via relativeTo.
    static func jb(_ style: Font.TextStyle) -> Font {
        .custom(Self.jb_name, size: Self.point_size(for: style), relativeTo: style)
    }

    // JetBrains Mono at a fixed point size (menu-bar glyph letters).
    static func jb(size: CGFloat) -> Font {
        .custom(Self.jb_name, fixedSize: size)
    }

    private static let jb_name = "JetBrainsMono-Regular"

    private static func point_size(for style: Font.TextStyle) -> CGFloat {
        let ns: NSFont.TextStyle
        switch style {
        case .largeTitle: ns = .largeTitle
        case .title: ns = .title1
        case .title2: ns = .title2
        case .title3: ns = .title3
        case .headline: ns = .headline
        case .subheadline: ns = .subheadline
        case .body: ns = .body
        case .callout: ns = .callout
        case .footnote: ns = .footnote
        case .caption: ns = .caption1
        case .caption2: ns = .caption2
        @unknown default: ns = .body
        }
        return NSFont.preferredFont(forTextStyle: ns).pointSize
    }
}
