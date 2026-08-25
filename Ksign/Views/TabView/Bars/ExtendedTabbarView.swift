//
//  ExtendedTabbarView.swift
//  KINDA
//

import SwiftUI

@available(iOS 18, *)
struct ExtendedTabbarView: View {

    @AppStorage("Feather.tabCustomization")
    private var customization = TabViewCustomization()

    var body: some View {
        TabView {
            ForEach(TabEnum.defaultTabs, id: \.self) { tab in
                Tab(
                    tab.title,
                    systemImage: tab.icon
                ) {
                    TabEnum.view(for: tab)
                }
                .customizationID("tab.\(tab.rawValue)")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
    }
}
