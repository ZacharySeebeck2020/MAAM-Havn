//
//  HavnTheme.swift
//  Havn
//
//  Created by Zac Seebeck on 8/12/25.
//

import SwiftUI

enum HavnTheme {

    // Corners
    enum Radius {
        static let card: CGFloat   = 20        // cards / big surfaces
        static let bubble: CGFloat = 12        // snippet bubble
    }

    // Strokes
    enum Stroke {
        static let cardOpacity: CGFloat = 0.22 // 20–25% target
        static let bubbleOpacity: CGFloat = 0.15
    }

    // Typography
    enum Typeface {
        // Display / big titles (e.g., “Journal”)
        static var display: Font  { .system(size: 34, weight: .bold, design: .rounded) }

        // Section / header titles (day header, month title)
        static var title: Font    { .system(.title2, design: .rounded).weight(.semibold) }
        static var headline: Font { .system(.headline, design: .rounded).weight(.semibold) }

        // Body & UI
        static var body: Font     { .system(.body, design: .default) }
        static var callout: Font  { .system(.callout, design: .default) }
        static var footnote: Font { .system(.footnote, design: .default) }
        static var caption: Font  { .system(.caption, design: .default) }

        // Calendar-specific
        static var weekday: Font  { .system(.caption2, design: .rounded).weight(.semibold) } // MON TUE …
        static var dayNumber: Font { .system(.callout, design: .rounded).weight(.semibold) } // 1–31
    }

    // MARK: - Modifiers

    /// 1pt accent stroke around rounded surfaces
    struct CardStroke: ViewModifier {
        func body(content: Content) -> some View {
            content.overlay(
                RoundedRectangle(cornerRadius: HavnTheme.Radius.card, style: .continuous)
                    .strokeBorder(Color("AccentColor").opacity(0.4), lineWidth: 2)
            )
        }
    }

    /// Bottom fade overlay (clear → black 55%) over the lower ~40% of the view
    struct BottomFade: ViewModifier {
        var maxOpacity: CGFloat = 0.55
        /// where the fade begins, 0 = top, 1 = bottom (e.g. 0.60 = bottom 40%)
        var startLocation: CGFloat = 0.60

        func body(content: Content) -> some View {
            content.overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: startLocation),
                        .init(color: .black.opacity(maxOpacity), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
        }
    }

    /// Snippet bubble background: material + subtle stroke
    struct BubbleBackground: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous)
                        .stroke(.white.opacity(Stroke.bubbleOpacity), lineWidth: 1)
                )
        }
    }
}

// Sugar
extension View {
    func havnCardStroke() -> some View { modifier(HavnTheme.CardStroke()) }
    func havnBottomFade(maxOpacity: CGFloat = 0.55, startLocation: CGFloat = 0.60) -> some View {
        modifier(HavnTheme.BottomFade(maxOpacity: maxOpacity, startLocation: startLocation))
    }
    func havnBubbleBackground() -> some View { modifier(HavnTheme.BubbleBackground()) }
}
