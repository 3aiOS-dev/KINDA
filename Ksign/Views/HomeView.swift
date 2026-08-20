//
//  HomeView.swift
//  Ksign
//
//  متجر KINDA — تصميم كامل مطابق للصور
//  بدون تقييم نجوم وبدون عدد التحميلات
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - Theme

enum KindaTheme {

    static let purple = Color(red: 0.35, green: 0.20, blue: 0.95)
    static let purpleLight = Color(red: 0.58, green: 0.42, blue: 0.98)

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [purpleLight, purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardBG: Color { Color(.secondarySystemGroupedBackground) }
    static var pageBG: Color { Color(.systemBackground) }
    static var chipBG: Color { Color.secondary.opacity(0.12) }
}

// MARK: - Home View (Store Only)

struct HomeView: View {

    // MARK: Managers
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var storeManager = KindaStoreManager.shared

    // MARK: State
    @State private var searchText = ""
    @State private var selectedCategory = "الكل"
    @State private var selectedApp: StoreApp?
    @State private var bannerIndex = 0

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
            if !list.contains(app.category) {
                list.append(app.category)
            }
        }
        return list
    }

    private var visibleApps: [StoreApp] {
        storeManager.filtered(searchText).filter { app in
            selectedCategory == "الكل" || app.category == selectedCategory
        }
    }

    /// البنر يعرض التطبيقات المضافة في المتجر (أحدثها أولاً)
    private var bannerApps: [StoreApp] {
        Array(storeManager.apps.prefix(5))
    }

    private var featuredApps: [StoreApp] {
        Array(storeManager.apps.prefix(8))
    }

    // MARK: Body

    var body: some View {

        ZStack(alignment: .top) {

            KindaTheme.pageBG.ignoresSafeArea()

            VStack(spacing: 0) {

                header
                searchBar

                Divider().opacity(0.4)

                ScrollView(showsIndicators: false) {

                    VStack(alignment: .leading, spacing: 24) {

                        if searchText.isEmpty, !bannerApps.isEmpty {
                            bannerSection
                            featuredSection
                        }

                        categoriesRow
                        allAppsSection
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    await storeManager.load()
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            if storeManager.apps.isEmpty {
                await storeManager.load()
            }
        }
        .fullScreenCover(item: $selectedApp) { app in
            StoreAppDetailView(
                app: app,
                onDownloadStarted: { download in
                    watchStoreDownload(download, app: app)
                }
            )
        }
        .onDisappear {
            for task in downloadWatchTasks.values { task.cancel() }
            downloadWatchTasks.removeAll()
        }
    }

    // MARK: Header

    private var header: some View {

        HStack(spacing: 12) {

            HStack(spacing: 10) {

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(KindaTheme.gradient)
                        .frame(width: 46, height: 46)

                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .trailing, spacing: 0) {

                    Text("KINDA")
                        .font(.system(size: 20, weight: .heavy))

                    Text("متجر التطبيقات")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {

                headerIcon("square.grid.2x2.fill", active: true)
                headerIcon("bell", active: false)
                headerIcon("shield", active: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func headerIcon(_ name: String, active: Bool) -> some View {

        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(active ? Color.white : Color.primary)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(active ? AnyShapeStyle(KindaTheme.gradient) : AnyShapeStyle(Color.clear))
            )
    }

    // MARK: Search

    private var searchBar: some View {

        HStack(spacing: 10) {

            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("ابحث عن تطبيق...", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.callout)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: Banner (التطبيقات المضافة)

    private var bannerSection: some View {

        VStack(spacing: 12) {

            TabView(selection: $bannerIndex) {

                ForEach(Array(bannerApps.enumerated()), id: \.element.id) { index, app in

                    bannerCard(app)
                        .tag(index)
                        .padding(.horizontal, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 190)

            // نقاط الصفحات
            HStack(spacing: 6) {

                ForEach(bannerApps.indices, id: \.self) { i in

                    Capsule()
                        .fill(i == bannerIndex ? KindaTheme.purple : Color.secondary.opacity(0.3))
                        .frame(width: i == bannerIndex ? 22 : 7, height: 7)
                        .animation(.snappy, value: bannerIndex)
                }
            }
        }
    }

    private func bannerCard(_ app: StoreApp) -> some View {

        Button {
            selectedApp = app
        } label: {

            ZStack {

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(KindaTheme.gradient)

                HStack(spacing: 14) {

                    VStack(alignment: .trailing, spacing: 8) {

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                            Text("تطبيق اليوم")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.22)))
                        .foregroundStyle(Color.white)

                        Text(app.name)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)

                        if !app.appDescription.isEmpty {
                            Text(app.appDescription)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.9))
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack(spacing: 4) {
                            Text("عرض التفاصيل")
                                .font(.footnote.weight(.bold))
                            Image(systemName: "chevron.forward")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Color.white)
                    }

                    Spacer(minLength: 0)

                    StoreIconView(urlString: app.iconURL, size: 96)
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                }
                .padding(18)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Featured

    private var featuredSection: some View {

        VStack(alignment: .trailing, spacing: 12) {

            VStack(alignment: .trailing, spacing: 2) {

                Text("مميزة")
                    .font(.title2.weight(.heavy))

                Text("تطبيقات مختارة بعناية")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {

                HStack(spacing: 12) {

                    ForEach(featuredApps) { app in

                        Button {
                            selectedApp = app
                        } label: {
                            featuredCard(app)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func featuredCard(_ app: StoreApp) -> some View {

        VStack(spacing: 10) {

            StoreIconView(urlString: app.iconURL, size: 92)

            VStack(spacing: 2) {

                Text(app.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)

                Text(app.category.isEmpty ? "KINDA" : app.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(app.sizeText ?? "v\(app.version)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(KindaTheme.cardBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: Categories

    private var categoriesRow: some View {

        Group {

            if categories.count > 1 {

                ScrollView(.horizontal, showsIndicators: false) {

                    HStack(spacing: 10) {

                        ForEach(categories, id: \.self) { category in

                            Button {
                                withAnimation(.snappy) { selectedCategory = category }
                            } label: {

                                Text(category)
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(
                                                selectedCategory == category
                                                ? AnyShapeStyle(KindaTheme.gradient)
                                                : AnyShapeStyle(KindaTheme.chipBG)
                                            )
                                    )
                                    .foregroundStyle(
                                        selectedCategory == category ? Color.white : Color.primary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: All Apps

    private var allAppsSection: some View {

        VStack(alignment: .trailing, spacing: 14) {

            VStack(alignment: .trailing, spacing: 2) {

                Text("كل التطبيقات")
                    .font(.title2.weight(.heavy))

                Text("\(visibleApps.count) تطبيق")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 16)

            if visibleApps.isEmpty, !storeManager.isLoading {

                VStack(spacing: 8) {

                    Image(systemName: "bag")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)

                    Text("لا توجد تطبيقات")
                        .font(.headline)

                    Text("لم يتم إضافة أي تطبيق إلى المتجر بعد.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)

            } else {

                LazyVStack(spacing: 14) {

                    ForEach(visibleApps) { app in

                        StoreCellView(app: app) {
                            selectedApp = app
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Store Download Handling

extension HomeView {

    /// يبدأ DownloadManager تنزيل IPA الحقيقي من ipa_url، ثم ينتظر حتى ينتهي
    /// DownloadManager من معالجة الملف وإضافته إلى Imported/Core Data.
    private func watchStoreDownload(_ download: Download, app: StoreApp) {

        let downloadID = download.id

        downloadWatchTasks[downloadID]?.cancel()
        pendingStoreDownloads.insert(downloadID)

        let task = Task { @MainActor in

            var reachedDownloadCompletion = false

            while !Task.isCancelled {

                if let currentDownload = DownloadManager.shared.getDownload(by: downloadID) {
                    if currentDownload.totalBytes > 0,
                       currentDownload.progress >= 0.999 {
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case bundleId = "bundle_id"
        case appDescription = "description"
        case category
        case iconURL = "icon_url"
        case ipaURL = "ipa_url"
        case sizeMB = "size_mb"
    }

    /// نص الحجم جاهز للعرض (MB أو GB) — يرجع nil إن لم يُضف حجم.
    var sizeText: String? {

        guard let sizeMB, sizeMB > 0 else { return nil }

        if sizeMB >= 1024 {
            return String(format: "%.2f GB", sizeMB / 1024)
        }

        return String(format: "%.0f MB", sizeMB)
    }

    /// معرّف مختصر (آخر جزء من bundle id)
    var shortIdentifier: String {
        bundleId.split(separator: ".").last.map(String.init) ?? bundleId
    }
}

// MARK: - Store Manager

@MainActor
final class KindaStoreManager: ObservableObject {

    static let shared = KindaStoreManager()

    // بيانات الاتصال بلوحة التحكم (Lovable Cloud)
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

        guard
            let url = URL(
                string: "\(baseURL)/rest/v1/store_apps?select=*&order=created_at.desc"
            )
        else { return }

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

// MARK: - Store Cell

struct StoreCellView: View {

    let app: StoreApp
    var onTap: () -> Void = {}

    var body: some View {

        HStack(spacing: 12) {

            StoreIconView(urlString: app.iconURL, size: 62)

            VStack(alignment: .trailing, spacing: 3) {

                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("KINDA")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {

                    if let size = app.sizeText {
                        Text(size)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text("v\(app.version)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button(action: onTap) {

                Text("عرض")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(KindaTheme.purple)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(KindaTheme.purple.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Store Icon

struct StoreIconView: View {

    let urlString: String
    let size: CGFloat

    var body: some View {

        AsyncImage(url: URL(string: urlString)) { image in

            image
                .resizable()
                .scaledToFill()

        } placeholder: {

            RoundedRectangle(cornerRadius: size / 4.5, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .overlay(
                    Image(systemName: "app.dashed")
                        .font(.system(size: size / 3, weight: .light))
                        .foregroundStyle(.secondary)
                )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 4.5, style: .continuous))
    }
}

// MARK: - App Detail Screen

struct StoreAppDetailView: View {

    let app: StoreApp
    let onDownloadStarted: (Download) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var activeDownloadID: String?

    var body: some View {

        ZStack(alignment: .top) {

            KindaTheme.pageBG.ignoresSafeArea()

            VStack(spacing: 0) {

                detailHeader

                Divider().opacity(0.4)

                ScrollView(showsIndicators: false) {

                    VStack(alignment: .trailing, spacing: 22) {

                        backButton
                        heroCard
                        downloadButton
                        infoGrid
                        aboutSection
                        whatsNewSection
                        additionalInfoSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onReceive(downloadManager.$downloads) { downloads in
            guard let activeDownloadID else { return }
            if downloads.contains(where: { $0.id == activeDownloadID }) == false {
                self.activeDownloadID = nil
            }
        }
    }

    // MARK: Header

    private var detailHeader: some View {

        HStack(spacing: 12) {

            HStack(spacing: 10) {

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(KindaTheme.gradient)
                        .frame(width: 46, height: 46)

                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .trailing, spacing: 0) {

                    Text("KINDA")
                        .font(.system(size: 20, weight: .heavy))

                    Text("متجر التطبيقات")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 14) {

                Image(systemName: "square.grid.2x2")
                Image(systemName: "bell")
                Image(systemName: "shield")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var backButton: some View {

        Button {
            dismiss()
        } label: {

            HStack(spacing: 8) {

                Text("رجوع")
                    .font(.title3.weight(.bold))

                Image(systemName: "arrow.left")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: Hero

    private var heroCard: some View {

        VStack(spacing: 12) {

            StoreIconView(urlString: app.iconURL, size: 130)
                .shadow(color: .black.opacity(0.15), radius: 14, y: 8)

            Text(app.name)
                .font(.system(size: 28, weight: .heavy))
                .multilineTextAlignment(.center)

            Text("KINDA")
                .font(.title3)
                .foregroundStyle(.secondary)

            if !app.category.isEmpty {

                Text(app.category)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            KindaTheme.purple.opacity(0.10),
                            KindaTheme.purple.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    // MARK: Download Button

    private var downloadButton: some View {

        Button {
            install()
        } label: {

            HStack(spacing: 10) {

                if activeDownloadID != nil {

                    ProgressView()
                        .tint(Color.white)

                    Text("جاري التنزيل...")
                        .font(.headline.weight(.bold))

                } else {

                    Image(systemName: "arrow.down.circle")
                        .font(.headline.weight(.bold))

                    Text(
                        app.sizeText.map { "تنزيل التطبيق · \($0)" } ?? "تنزيل التطبيق"
                    )
                    .font(.headline.weight(.bold))
                }
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(KindaTheme.purple)
            )
        }
        .buttonStyle(.plain)
        .disabled(activeDownloadID != nil)
    }

    // MARK: Info Grid

    private var infoGrid: some View {

        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {

            infoCard(icon: "tag", title: "الإصدار", value: app.version)
            infoCard(icon: "externaldrive", title: "الحجم", value: app.sizeText ?? "—")
            infoCard(icon: "shippingbox", title: "التصنيف", value: app.category)
            infoCard(icon: "sparkles", title: "المعرّف", value: app.shortIdentifier)
        }
    }

    private func infoCard(icon: String, title: String, value: String) -> some View {

        VStack(spacing: 6) {

            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(KindaTheme.purple)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "—" : value)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(KindaTheme.cardBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: About

    private var aboutSection: some View {

        Group {

            if !app.appDescription.isEmpty {

                VStack(alignment: .trailing, spacing: 10) {

                    Text("عن التطبيق")
                        .font(.title3.weight(.heavy))

                    Text(app.appDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: What's New

    private var whatsNewSection: some View {

        VStack(alignment: .trailing, spacing: 10) {

            Text("الجديد في هذا الإصدار")
                .font(.title3.weight(.heavy))

            Text("الإصدار \(app.version) — تحسينات في الأداء وإصلاح مشاكل عامة.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: Additional Info

    private var additionalInfoSection: some View {

        VStack(alignment: .trailing, spacing: 10) {

            Text("معلومات إضافية")
                .font(.title3.weight(.heavy))

            VStack(spacing: 0) {

                infoRow(title: "Bundle ID", value: app.bundleId, mono: true)
                Divider()
                infoRow(title: "الإصدار", value: app.version, mono: true)
                Divider()
                infoRow(title: "المطوّر", value: "KINDA", mono: true)
                Divider()
                infoRow(title: "الحجم", value: app.sizeText ?? "—", mono: true)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(KindaTheme.cardBG)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func infoRow(title: String, value: String, mono: Bool) -> some View {

        HStack {

            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value.isEmpty ? "—" : value)
                .font(mono ? .callout.monospaced().weight(.semibold) : .callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Install Action

    private func install() {

        guard
            let url = URL(string: app.ipaURL),
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized("The IPA URL is invalid.")
            )
            return
        }

        let downloadID = "KindaStore_\(app.id)"

        // DownloadManager يقوم بالتنزيل الفعلي عبر URLSession، ثم ينقل
        // الملف إلى مجلد التنزيلات ويستدعي FR.handlePackageFile لإضافته
        // إلى Imported/Core Data بعد اكتمال التنزيل.
        let download = downloadManager.startDownload(from: url, id: downloadID)

        activeDownloadID = download.id
        onDownloadStarted(download)
    }
}
