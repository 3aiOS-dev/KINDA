import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case home // تم التغيير هنا من files إلى home
    case sources
    case library
    case settings
    case certificates
    case search // تبويب البحث - منفصل عن باقي التبويبات، يظهر كأيقونة عائمة مستقلة زي الدائرة السوداء بالصورة

    var title: String {
        switch self {
        case .home:
            return .localized("الرئيسية") // يمكنك جعلها "Home" إذا كان التطبيق بالإنجليزية
        case .sources:
            return .localized("Sources")
        case .library:
            return .localized("Library")
        case .settings:
            return .localized("Settings")
        case .certificates:
            return .localized("Certificates")
        case .search:
            return .localized("بحث")
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill" // تم تغيير الأيقونة لتناسب الرئيسية
        case .sources:
            return "globe.desk"
        case .library:
            return "square.grid.2x2"
        case .settings:
            return "gearshape.2"
        case .certificates:
            return "person.text.rectangle"
        case .search:
            // نفس مكان الدائرة السوداء العائمة بالصورة، لكن بدل علامة + صارت أيقونة بحث
            return "magnifyingglass"
        }
    }

    @ViewBuilder
    static func view(for tab: TabEnum) -> some View {
        switch tab {
        case .home:
            HomeView() // توجيه التبويب إلى الشاشة الجديدة

        case .sources:
            SourcesView()

        case .library:
            LibraryView()

        case .settings:
            SettingsView()

        case .certificates:
            NBNavigationView(.localized("Certificates")) {
                CertificatesView()
            }

        case .search:
            // زر البحث العائم يفتح شاشة الرئيسية مباشرة مع تفعيل مربع البحث تلقائياً
            HomeView(autoFocusSearch: true)
        }
    }

    static var defaultTabs: [TabEnum] {
        [
            .home, // تم التحديث هنا
            .library,
            .settings
        ]
    }

    static var customizableTabs: [TabEnum] {
        [
            .certificates
        ]
    }

    /// التبويبات اللي لازم تترسم منفصلة عن الشريط الرئيسي (زي الدائرة السوداء العائمة بالصورة)
    /// بدل ما تكون جزء من نفس الكبسولة اللي فيها باقي الأيقونات على اليسار.
    static var floatingTabs: [TabEnum] {
        [
            .search
        ]
    }

    /// اسم الإشعار المستخدم لفتح شاشة الرئيسية مع تفعيل البحث مباشرة
    /// من أي مكان بالتطبيق (نفس أسلوب "ksign.openLibraryTab" المستخدم في HomeView).
    static let openHomeSearchNotification = Notification.Name("ksign.openHomeSearch")
}
