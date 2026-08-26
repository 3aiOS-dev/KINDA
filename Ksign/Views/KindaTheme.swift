//
// KindaTheme.swift
// KINDA
//

import SwiftUI

enum KindaTheme {
    static let purple = Color(red: 0.35, green: 0.20, blue: 0.95)
    static let purpleLight = Color(red: 0.58, green: 0.42, blue: 0.98)

    static var cardBG: Color {
        Color(.secondarySystemGroupedBackground)
    }

    static var pageBG: Color {
        Color(.systemBackground)
    }

    static var chipBG: Color {
        Color.secondary.opacity(0.12)
    }
}

struct KindaGridBackground: View {
    private let spacing: CGFloat = 48
    private let lineOpacity: Double = 0.045

    var body: some View {
        Canvas { context, size in
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(
                path,
                with: .color(.primary.opacity(lineOpacity)),
                lineWidth: 0.7
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
