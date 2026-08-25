import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case home
    case library
    case settings

    var title: String {
        switch self {
        case .home:
            return "الرئيسية"
        case .library:
            return "توقيع"
        case .settings:
            return "الإعدادات"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .library:
            return "signature"
        case .settings:
            return "gearshape.2"
        }
    }

    @ViewBuilder
    static func view(for tab: TabEnum) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .library:
            LibraryView()
        case .settings:
            SettingsView()
        }
    }

    static var defaultTabs: [TabEnum] {
        [
            .home,
            .library,
            .settings
        ]
    }

    // يمنع ظهور "المزيد" أو تبويبات إضافية في iOS 18.
    static var customizableTabs: [TabEnum] {
        []
    }
}
