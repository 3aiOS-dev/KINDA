//
//  TabbarView.swift
//  KINDA
//

import SwiftUI

struct TabbarView: View {

    @State private var selectedTab: TabEnum = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TabEnum.defaultTabs, id: \.self) { tab in
                TabEnum.view(for: tab)
                    .tabItem {
                        Label(
                            tab.title,
                            systemImage: tab.icon
                        )
                    }
                    .tag(tab)
            }
        }
    }
}
