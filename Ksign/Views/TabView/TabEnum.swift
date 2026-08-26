//
// TabEnum.swift
// KINDA
//
// النسخة الجديدة: لا يوجد تبويب "توقيع".
// التبويبات الظاهرة فقط: الرئيسية + الإعدادات.
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
    static func view(for tab: TabEnum) -> some View {
        switch tab {
        case .home:
            HomeView()

        case .settings:
            SettingsView()
        }
    }

    // التبويبات الأساسية فقط.
    static var defaultTabs: [TabEnum] {
        [
            .home,
            .settings
        ]
    }

    // لا توجد أي تبويبات إضافية أو "المزيد".
    static var customizableTabs: [TabEnum] {
        []
    }
}
