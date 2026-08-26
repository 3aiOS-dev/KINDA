//
// TabEnum.swift
// KINDA
//
// فقط الرئيسية والإعدادات.
// لا يوجد تبويب توقيع ولا مكتبة ولا المزيد.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case home
    case settings

    var title: String {
        switch self {
        case .home:
            return "الرئيسية"
        case .settings:
            return "الإعدادات"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .settings:
            return "gearshape.2"
        }
    }

    @ViewBuilder
    @MainActor
    static func view(
        for tab: TabEnum
    ) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .settings:
            SettingsView()
        }
    }

    static var defaultTabs:
        [TabEnum] {
        [
            .home,
            .settings
        ]
    }

    static var customizableTabs:
        [TabEnum] {
        []
    }
}
