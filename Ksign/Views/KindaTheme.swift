//
// KindaTheme.swift
// KINDA
//
// Lightweight theme definitions kept in one file so Settings screens
// do not depend on a removed/custom theme package.
//

import SwiftUI

enum KindaTheme {
    static let pageBG = Color(uiColor: .systemGroupedBackground)
}

/// خلفية محايدة وخفيفة. لا تعتمد على أي موارد خارجية.
struct KindaGridBackground: View {
    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
