import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case home
    case library
    case settings
    case certificates

    var title: String {
        switch self {
        case .home:
            return .localized("الرئيسية")

        case .library:
            return .localized("المكتبة")

        case .settings:
            return .localized("الإعدادات")

        case .certificates:
            return .localized("الشهادات")
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"

        case .library:
            return "square.grid.2x2.fill"

        case .settings:
            return "gearshape.2.fill"

        case .certificates:
            return "person.text.rectangle.fill"
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
            SettingsWithCertificatesView()

        case .certificates:
            NBNavigationView(.localized("الشهادات")) {
                CertificatesView()
            }
        }
    }

    // التبويبات الرئيسية فقط.
    // لا يوجد More ولا Sources ولا Certificates هنا.
    static var defaultTabs: [TabEnum] {
        [
            .home,
            .library,
            .settings
        ]
    }

    // تعطيل التبويبات الإضافية بالكامل.
    // هذا يمنع ظهور More أو Certificates عند تدوير الجهاز.
    static var customizableTabs: [TabEnum] {
        []
    }
}

// MARK: - الإعدادات مع الشهادات

private struct SettingsWithCertificatesView: View {
    @State private var showCertificates = false

    var body: some View {
        SettingsView()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCertificates = true
                    } label: {
                        Image(systemName: TabEnum.certificates.icon)
                    }
                    .accessibilityLabel(
                        .localized("الشهادات")
                    )
                }
            }
            .sheet(isPresented: $showCertificates) {
                NBNavigationView(.localized("الشهادات")) {
                    CertificatesView()
                }
            }
    }
}
