//
//  HomeView.swift
//  Ksign
//
//  متجر KINDA — تصميم مطابق لواجهة App Store (RTL)
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - Home View (App Store Style)

struct HomeView: View {

    // MARK: Managers
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var storeManager = KindaStoreManager.shared

    // MARK: State
    @State private var searchText = ""
    @State private var selectedCategory = "الكل"
    @State private var selectedApp: StoreApp?

    // تنزيلات المتجر التي تنتظر اكتمال الاستيراد إلى المكتبة
    @State private var pendingStoreDownloads: Set<String> = []
    @State private var downloadWatchTasks: [String: Task<Void, Never>] = [:]

    // MARK: Core Data (لمتابعة اكتمال الاستيراد فقط)
    @FetchRequest(
        entity: Imported.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Imported.date, ascending: false)
        ],
        animation: .snappy
    )
    private var importedApps: FetchedResults<Imported>

    // MARK: Derived

    private var categories: [String] {
        var list = ["الكل"]
        for app in storeManager.apps where !app.category.isEmpty {
            if !list.contains(app.category) { list.append(app.category) }
        }
        return list
    }

    private var visibleApps: [StoreApp] {
        storeManager.filtered(searchText).filter { app in
            selectedCategory == "الكل" || app.category == selectedCategory
        }
    }

    /// البطاقات الكبيرة الأفقية (أول 5 تطبيقات)
    private var featuredApps: [StoreApp] {
        Array(visibleApps.prefix(5))
    }

    /// بقية التطبيقات تظهر في قائمة "ما نلعبه الآن"
    private var listApps: [StoreApp] {
        visibleApps.count > 5 ? Array(visibleApps.dropFirst(5)) : visibleApps
    }

    // MARK: Body

    var body: some View {
        NBNavigationView(.localized("المتجر")) {

            ScrollView {

                LazyVStack(alignment: .leading, spacing: 26, pinnedViews: []) {

                    // MARK: Categories (كبسولات أعلى الصفحة)

                    if categories.count > 1 {
                        categoriesRow
                    }

                    // MARK: Featured Carousel

                    if !featuredApps.isEmpty {
                        featuredCarousel
                    }

                    // MARK: What We're Playing

                    if !listApps.isEmpty {
                        sectionHeader(.localized("ما نُثبّته الآن"))
                        appsList
                    }

                    Color.clear.frame(height: 24)
                }
                .padding(.top, 4)
            }
            .background(Color(.systemBackground))
            .scrollIndicators(.hidden)
            .refreshable { await storeManager.load() }

            // MARK: Store Loading

            .task {
                if storeManager.apps.isEmpty { await storeManager.load() }
            }

            // MARK: Search

            .searchable(text: $searchText, placement: .platform())

            // MARK: Empty State

            .overlay {
                if visibleApps.isEmpty, !storeManager.isLoading {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label(.localized("لا توجد تطبيقات"), systemImage: "bag")
                        } description: {
                            Text(.localized("لم يتم إضافة أي تطبيق إلى المتجر بعد."))
                        }
                    }
                }
            }

            // MARK: App Detail

            .fullScreenCover(item: $selectedApp) { app in
                StoreAppDetailView(
                    app: app,
                    onDownloadStarted: { download in
                        watchStoreDownload(download, app: app)
                    }
                )
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onDisappear {
            for task in downloadWatchTasks.values { task.cancel() }
            downloadWatchTasks.removeAll()
        }
    }

    // MARK: - Sections

    private var categoriesRow: some View {

        ScrollView(.horizontal, showsIndicators: false) {

            HStack(spacing: 10) {

                ForEach(categories, id: \.self) { category in

                    Button {
                        withAnimation(.snappy) { selectedCategory = category }
                    } label: {

                        HStack(spacing: 6) {

                            Image(systemName: Self.icon(for: category))
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(
                                    selectedCategory == category
                                    ? Color.white
                                    : Color.accentColor
                                )

                            Text(category)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(
                                    selectedCategory == category
                                    ? Color.white
                                    : Color.primary
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                selectedCategory == category
                                ? Color.accentColor
                                : Color(.secondarySystemBackground)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                Color.primary.opacity(selectedCategory == category ? 0 : 0.06)
                            )
                        )
                        .shadow(
                            color: .black.opacity(0.06),
                            radius: 6, x: 0, y: 3
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private var featuredCarousel: some View {

        ScrollView(.horizontal, showsIndicators: false) {

            HStack(spacing: 14) {

                ForEach(featuredApps) { app in

                    Button {
                        selectedApp = app
                    } label: {
                        FeaturedCardView(app: app) { install(app) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    private var appsList: some View {

        VStack(spacing: 0) {

            ForEach(Array(listApps.enumerated()), id: \.element.id) { index, app in

                Button {
                    selectedApp = app
                } label: {
                    StoreCellView(app: app) { install(app) }
                }
                .buttonStyle(.plain)

                if index != listApps.count - 1 {
                    Divider().padding(.leading, 16).padding(.trailing, 84)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {

        HStack(spacing: 6) {

            Text(title)
                .font(.title2.bold())

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }

    private func install(_ app: StoreApp) {
        if let download = StoreInstaller.install(app) {
            watchStoreDownload(download, app: app)
        }
    }

    static func icon(for category: String) -> String {
        switch category {
        case "الكل":            return "square.grid.2x2.fill"
        case "ألغاز":           return "puzzlepiece.extension.fill"
        case "عائلة":           return "person.2.fill"
        case "ألعاب محاكاة":    return "cube.fill"
        case "تسلية":           return "gamecontroller.fill"
        case "مغامرة":          return "map.fill"
        case "أدوات":           return "wrench.and.screwdriver.fill"
        case "شبكات اجتماعية":  return "bubble.left.and.bubble.right.fill"
        default:                 return "app.badge.fill"
        }
    }
}

// MARK: - Store Download Handling

extension HomeView {

    private func watchStoreDownload(_ download: Download, app: StoreApp) {

        let downloadID = download.id

        downloadWatchTasks[downloadID]?.cancel()
        pendingStoreDownloads.insert(downloadID)

        let task = Task { @MainActor in

            var reachedDownloadCompletion = false

            while !Task.isCancelled {
                if let currentDownload = DownloadManager.shared.getDownload(by: downloadID) {
                    if currentDownload.totalBytes > 0, currentDownload.progress >= 0.999 {
                        reachedDownloadCompletion = true
                    }
                } else {
                    break
                }

                try? await Task.sleep(nanoseconds: 300_000_000)
            }

            guard !Task.isCancelled else { return }

            try? await Task.sleep(nanoseconds: 500_000_000)

            let importedSuccessfully = importedApps.contains { imported in
                guard let name = imported.name else { return false }
                return name.localizedCaseInsensitiveCompare(app.name) == .orderedSame
            }

            pendingStoreDownloads.remove(downloadID)
            downloadWatchTasks[downloadID] = nil

            guard reachedDownloadCompletion || importedSuccessfully else {
                UIAlertController.showAlertWithOk(
                    title: .localized("Error"),
                    message: .localized("The IPA download or import could not be completed.")
                )
                return
            }

            NotificationCenter.default.post(
                name: NSNotification.Name("ksign.openLibraryTab"),
                object: nil
            )
        }

        downloadWatchTasks[downloadID] = task
    }
}

// MARK: - Store Model (Lovable Cloud)

struct StoreApp: Identifiable, Decodable, Hashable {

    let id: String
    let name: String
    let version: String
    let bundleId: String
    let appDescription: String
    let category: String
    let iconURL: String
    let ipaURL: String
    let sizeMB: Double?

    // حقول اختيارية لواجهة App Store (تعمل حتى لو غير موجودة في القاعدة)
    let bannerURL: String?
    let screenshots: [String]?
    let developer: String?
    let rating: Double?
    let ratingCount: Int?
    let ageRating: String?
    let rank: Int?
    let hasIAP: Bool?
    let tagline: String?

    enum CodingKeys: String, CodingKey {
        case id, name, version, category, screenshots, developer, rating, rank, tagline
        case bundleId = "bundle_id"
        case appDescription = "description"
        case iconURL = "icon_url"
        case ipaURL = "ipa_url"
        case sizeMB = "size_mb"
        case bannerURL = "banner_url"
        case ratingCount = "rating_count"
        case ageRating = "age_rating"
        case hasIAP = "has_iap"
    }

    var sizeText: String? {
        guard let sizeMB, sizeMB > 0 else { return nil }
        if sizeMB >= 1024 { return String(format: "%.2f GB", sizeMB / 1024) }
        return String(format: "%.0f MB", sizeMB)
    }

    /// صورة الغلاف الكبيرة للبطاقة المميزة
    var heroImageURL: String {
        if let bannerURL, !bannerURL.isEmpty { return bannerURL }
        if let first = screenshots?.first, !first.isEmpty { return first }
        return iconURL
    }

    var subtitleText: String {
        if let tagline, !tagline.isEmpty { return tagline }
        if !appDescription.isEmpty { return appDescription }
        return category
    }

    var developerName: String { developer ?? "KINDA" }
    var ratingValue: Double { rating ?? 0 }
    var ageRatingText: String { ageRating ?? "٤+" }
}

// MARK: - Store Manager

@MainActor
final class KindaStoreManager: ObservableObject {

    static let shared = KindaStoreManager()

    private let baseURL = "https://ibskoyypugseeixzntyt.supabase.co"
    private let apiKey = "sb_publishable_McRq3FTx_r7pL2PbGk8YBA_mMnJmtFm"

    @Published var apps: [StoreApp] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    func filtered(_ searchText: String) -> [StoreApp] {

        guard !searchText.isEmpty else { return apps }

        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    func load() async {

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(
            string: "\(baseURL)/rest/v1/store_apps?select=*&order=created_at.desc"
        ) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            apps = try JSONDecoder().decode([StoreApp].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared Installer

enum StoreInstaller {

    @MainActor
    @discardableResult
    static func install(_ app: StoreApp) -> Download? {

        guard
            let url = URL(string: app.ipaURL),
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized("The IPA URL is invalid.")
            )
            return nil
        }

        return DownloadManager.shared.startDownload(
            from: url,
            id: "KindaStore_\(app.id)"
        )
    }
}

// MARK: - Download Pill Button (زر "تنزيل" بشكل App Store)

struct DownloadPillButton: View {

    enum Style { case tinted, filled, glass }

    let title: String
    let style: Style
    let showsIAP: Bool
    let action: () -> Void

    @State private var isWorking = false

    init(
        title: String = .localized("تنزيل"),
        style: Style = .tinted,
        showsIAP: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.showsIAP = showsIAP
        self.action = action
    }

    var body: some View {

        VStack(spacing: 4) {

            Button {
                guard !isWorking else { return }
                isWorking = true
                action()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { isWorking = false }
            } label: {

                Group {
                    if isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                    }
                }
                .frame(minWidth: 76)
                .padding(.vertical, 7)
                .padding(.horizontal, 18)
                .background(background)
                .foregroundStyle(foreground)
            }
            .buttonStyle(.plain)

            if showsIAP {
                Text(.localized("الشراء داخل التطبيق"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .tinted: Capsule().fill(Color(.secondarySystemFill))
        case .filled: Capsule().fill(Color.accentColor)
        case .glass:  Capsule().fill(.ultraThinMaterial)
        }
    }

    private var foreground: Color {
        switch style {
        case .tinted: return .accentColor
        case .filled: return .white
        case .glass:  return .primary
        }
    }
}

// MARK: - Featured Card (البطاقة الكبيرة في الأعلى)

struct FeaturedCardView: View {

    let app: StoreApp
    let onInstall: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(.localized("تطبيق جديد"))
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .textCase(.none)

            Text(app.name)
                .font(.title3.bold())
                .lineLimit(1)

            Text(app.category.isEmpty ? app.subtitleText : app.category)
                .font(.title3.weight(.regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ZStack(alignment: .bottom) {

                StoreRemoteImage(urlString: app.heroImageURL)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // شريط سفلي زجاجي مثل App Store
                HStack(spacing: 10) {

                    DownloadPillButton(
                        style: .glass,
                        showsIAP: app.hasIAP ?? false,
                        action: onInstall
                    )

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 2) {

                        Text(app.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Text(app.category.isEmpty ? app.developerName : app.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    StoreIconView(urlString: app.iconURL, size: 44)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
        }
        .frame(width: 320)
    }
}

// MARK: - Store Cell (صف القائمة)

struct StoreCellView: View {

    let app: StoreApp
    var onInstall: (() -> Void)?

    var body: some View {

        HStack(spacing: 12) {

            StoreIconView(urlString: app.iconURL, size: 62)

            VStack(alignment: .leading, spacing: 2) {

                Text(app.name)
                    .font(.body.weight(.regular))
                    .lineLimit(1)

                Text(app.subtitleText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let size = app.sizeText {
                    Text("v\(app.version) • \(size)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            DownloadPillButton(
                style: .tinted,
                showsIAP: app.hasIAP ?? false,
                action: { onInstall?() }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Remote Image

struct StoreRemoteImage: View {

    let urlString: String

    var body: some View {

        AsyncImage(url: URL(string: urlString)) { phase in

            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color(.secondarySystemBackground)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            default:
                Color(.secondarySystemBackground)
                    .overlay(ProgressView())
            }
        }
    }
}

// MARK: - Store Icon

struct StoreIconView: View {

    let urlString: String
    let size: CGFloat

    var body: some View {

        StoreRemoteImage(urlString: urlString)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size / 4.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size / 4.5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
    }
}

// MARK: - App Detail Screen (مطابق لصفحة App Store)

struct StoreAppDetailView: View {

    let app: StoreApp
    let onDownloadStarted: (Download) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var activeDownloadID: String?
    @State private var isDescriptionExpanded = false

    private var progress: Double? {
        guard let activeDownloadID,
              let download = downloadManager.getDownload(by: activeDownloadID),
              download.totalBytes > 0
        else { return nil }
        return download.progress
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 0) {

                heroHeader

                headerRow
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                Divider().padding(.vertical, 18)

                statsRow

                Divider().padding(.vertical, 18)

                if let shots = app.screenshots, !shots.isEmpty {
                    screenshotsRow
                    Divider().padding(.vertical, 18)
                }

                descriptionSection
                    .padding(.horizontal, 16)

                Divider().padding(.vertical, 18)

                infoSection
                    .padding(.horizontal, 16)

                Color.clear.frame(height: 40)
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .scrollIndicators(.hidden)
        .environment(\.layoutDirection, .rightToLeft)
        .overlay(alignment: .top) { floatingControls }
        .onReceive(downloadManager.$downloads) { downloads in
            guard let activeDownloadID else { return }
            if downloads.contains(where: { $0.id == activeDownloadID }) == false {
                self.activeDownloadID = nil
            }
        }
    }

    // MARK: Hero

    private var heroHeader: some View {

        StoreRemoteImage(urlString: app.heroImageURL)
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .clipped()
    }

    private var floatingControls: some View {

        HStack {

            Button { dismiss() } label: {
                Image(systemName: "chevron.forward")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)

            Spacer()

            ShareLink(item: URL(string: app.ipaURL) ?? URL(string: "https://apple.com")!) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
    }

    // MARK: Header Row (أيقونة + اسم + زر تنزيل)

    private var headerRow: some View {

        HStack(alignment: .top, spacing: 14) {

            VStack(alignment: .leading, spacing: 6) {

                Text(app.name)
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(app.category.isEmpty ? app.developerName : app.category)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 10) {

                    installButton

                    if app.hasIAP ?? false {
                        Text(.localized("الشراء داخل التطبيق"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(width: 80, alignment: .leading)
                    }
                }
                .padding(.top, 6)
            }

            Spacer(minLength: 0)

            StoreIconView(urlString: app.iconURL, size: 118)
        }
    }

    private var installButton: some View {

        Button {
            install()
        } label: {

            Group {
                if let progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(.white)
                } else if activeDownloadID != nil {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Text(.localized("تنزيل"))
                        .font(.headline.weight(.bold))
                }
            }
            .frame(minWidth: 100)
            .padding(.vertical, 9)
            .padding(.horizontal, 18)
            .background(Capsule().fill(Color.accentColor))
            .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(activeDownloadID != nil)
    }

    // MARK: Stats Row (التقييم • التصنيف العمري • التصدر • المطور)

    private var statsRow: some View {

        ScrollView(.horizontal, showsIndicators: false) {

            HStack(spacing: 0) {

                statItem(
                    title: app.ratingCount.map { "\($0) تقييمًا" } ?? .localized("التقييم"),
                    value: app.ratingValue > 0
                        ? String(format: "%.1f", app.ratingValue)
                        : "—"
                ) {
                    AnyView(starsView)
                }

                statDivider

                statItem(
                    title: .localized("التصنيف العمري"),
                    value: app.ageRatingText
                ) {
                    AnyView(
                        Text(.localized("سنوات"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
                }

                statDivider

                statItem(
                    title: .localized("التصدر"),
                    value: app.rank.map { "#\($0)" } ?? "—"
                ) {
                    AnyView(
                        Text(app.category.isEmpty ? "—" : app.category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    )
                }

                statDivider

                statItem(
                    title: .localized("الحجم"),
                    value: app.sizeText ?? "—"
                ) {
                    AnyView(
                        Text("v\(app.version)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
                }

                statDivider

                statItem(title: .localized("المطور"), value: "") {
                    AnyView(
                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.square")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(app.developerName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var statDivider: some View {
        Divider().frame(height: 42).padding(.horizontal, 14)
    }

    private func statItem(
        title: String,
        value: String,
        @ViewBuilder footer: () -> AnyView
    ) -> some View {

        VStack(spacing: 4) {

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !value.isEmpty {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            footer()
        }
        .frame(minWidth: 82)
    }

    private var starsView: some View {

        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                Image(
                    systemName: Double(index) + 0.5 < app.ratingValue
                    ? "star.fill"
                    : (Double(index) < app.ratingValue ? "star.leadinghalf.filled" : "star")
                )
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Screenshots

    private var screenshotsRow: some View {

        ScrollView(.horizontal, showsIndicators: false) {

            HStack(spacing: 12) {

                ForEach(app.screenshots ?? [], id: \.self) { shot in

                    StoreRemoteImage(urlString: shot)
                        .frame(width: 240, height: 430)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Description

    private var descriptionSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            if !app.appDescription.isEmpty {

                Text(app.appDescription)
                    .font(.callout)
                    .lineSpacing(3)
                    .lineLimit(isDescriptionExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)

                if !isDescriptionExpanded {
                    Button(.localized("المزيد")) {
                        withAnimation(.snappy) { isDescriptionExpanded = true }
                    }
                    .font(.callout.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            Text(app.developerName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Info

    private var infoSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text(.localized("المعلومات"))
                .font(.title3.bold())

            infoRow(.localized("الإصدار"), app.version)
            Divider()
            infoRow(.localized("الفئة"), app.category.isEmpty ? "—" : app.category)
            Divider()
            infoRow(.localized("الحجم"), app.sizeText ?? "—")
            Divider()
            infoRow(.localized("التوافق"), "iPhone، iPad")
            Divider()
            infoRow(.localized("معرّف الحزمة"), app.bundleId, monospaced: true)
        }
    }

    private func infoRow(_ title: String, _ value: String, monospaced: Bool = false) -> some View {

        HStack(alignment: .firstTextBaseline) {

            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(monospaced ? .callout.monospaced() : .callout)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    // MARK: Install Action

    private func install() {

        guard let download = StoreInstaller.install(app) else { return }

        activeDownloadID = download.id
        onDownloadStarted(download)
    }
}
