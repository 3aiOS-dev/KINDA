import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case home
    case library
    case settings

    var title: String {
        switch self {
        case .home:
            return .localized("الرئيسية")

        case .library:
            return .localized("Library")

        case .settings:
            return .localized("Settings")
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"

        case .library:
            return "square.grid.2x2"

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

    static var customizableTabs: [TabEnum] {
        []
    }
}
