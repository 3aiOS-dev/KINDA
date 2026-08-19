//
//  TabEnum.swift
//  KINDA
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {

    case files
    case sources
    case library
    case settings
    case certificates

    // MARK: - Title

    var title: String {

        switch self {

        case .files:
            return .localized("Home")

        case .sources:
            return .localized("Sources")

        case .library:
            return .localized("Library")

        case .settings:
            return .localized("Settings")

        case .certificates:
            return .localized("Certificates")
        }
    }

    // MARK: - Icon

    var icon: String {

        switch self {

        case .files:
            return "house.fill"

        case .sources:
            return "globe.desk"

        case .library:
            return "square.grid.2x2"

        case .settings:
            return "gearshape.2"

        case .certificates:
            return "person.text.rectangle"
        }
    }

    // MARK: - View

    @ViewBuilder
    static func view(
        for tab: TabEnum
    ) -> some View {

        switch tab {

        case .files:
            HomeView()

        case .sources:
            SourcesView()

        case .library:
            LibraryView()

        case .settings:
            SettingsView()

        case .certificates:

            NBNavigationView(
                .localized("Certificates")
            ) {

                CertificatesView()
            }
        }
    }

    // MARK: - Default Tabs

    static var defaultTabs: [TabEnum] {

        [
            .files,
            .library,
            .settings
        ]
    }

    // MARK: - Customizable Tabs

    static var customizableTabs: [TabEnum] {

        [
            .certificates
        ]
    }
}
