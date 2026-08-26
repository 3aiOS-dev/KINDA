//
// TabbarView.swift
// KINDA
//

import SwiftUI

struct TabbarView: View {
    var body: some View {
        TabView {
            ForEach(
                TabEnum.defaultTabs,
                id: \.self
            ) { tab in
                TabEnum.view(for: tab)
                    .tabItem {
                        Label(
                            tab.title,
                            systemImage: tab.icon
                        )
                    }
            }
        }
    }
}
