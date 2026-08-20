//
//  HomeView.swift
//  Ksign
//
//  متجر KINDA — شاشة واحدة تعرض تطبيقات السيرفر فقط
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - Home View (Store Only)
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
            NSSortDescriptor(
                keyPath: \Imported.date,
                ascending: false
            )
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

    // MARK: Body

    var body: some View {
        NBNavigationView(.localized("المتجر")) {

            VStack(spacing: 0) {

                // MARK: Categories (تحت البحث)

                if categories.count > 1 {

                    ScrollView(.horizontal, showsIndicators: false) {

                        HStack(spacing: 8) {

                            ForEach(categories, id: \.self) { category in

                                Button {
                                    withAnimation(.snappy) {
                                        selectedCategory = category
                                    }
                                } label: {

                                    Text(category)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    selectedCategory == category
                                                    ? Color.accentColor
                                                    : Color.secondary.opacity(0.15)
                                                )
                                        )
                                        .foregroundStyle(
                                            selectedCategory == category
                                            ? Color.white
                                            : Color.primary
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                }

                // MARK: Apps List

                List {

                    ForEach(visibleApps) { app in

                        Button {
                            selectedApp = app
                        } label: {
                            StoreCellView(app: app)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await storeManager.load()
                }
            }

            // MARK: Store Loading

            .task {
                if storeManager.apps.isEmpty {
                    await storeManager.load()
                }
            }

            // MARK: Search

            .searchable(
                text: $searchText,
                placement: .platform()
            )

            // MARK: Empty State

            .overlay {

                if visibleApps.isEmpty, !storeManager.isLoading {

                    if #available(iOS 17, *) {

                        ContentUnavailableView {

                            Label(
                                .localized("لا توجد تطبيقات"),
                                systemImage: "bag"
                            )

                        } description: {

                            Text(
                                .localized("لم يتم إضافة أي تطبيق إلى المتجر بعد.")
                            )
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

        // MARK: Store Download State

        .onDisappear {
            for task in downloadWatchTasks.values {
                task.cancel()
            }
            downloadWatchTasks.removeAll()
        }
    }
}

// MARK: - Store Download Handling

extension HomeView {

    /// يبدأ DownloadManager تنزيل IPA الحقيقي من ipa_url، ثم ينتظر حتى ينتهي
    /// DownloadManager من معالجة الملف وإضافته إلى Imported/Core Data.
    private func watchStoreDownload(
        _ download: Download,
        app: StoreApp
    ) {
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

    var body: some View {

        HStack(spacing: 12) {

            StoreIconView(urlString: app.iconURL, size: 56)

            VStack(alignment: .leading, spacing: 3) {

                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !app.appDescription.isEmpty {
                    Text(app.appDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts = [app.category, "v\(app.version)"]
        if let size = app.sizeText { parts.append(size) }
        return parts.filter { !$0.isEmpty }.joined(separator: " • ")
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
                .fill(Color.secondary.opacity(0.2))
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(cornerRadius: size / 4.5, style: .continuous)
        )
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

        NavigationView {

            ScrollView {

                VStack(alignment: .leading, spacing: 22) {

                    // رأس التطبيق
                    HStack(alignment: .center, spacing: 16) {

                        StoreIconView(urlString: app.iconURL, size: 96)

                        VStack(alignment: .leading, spacing: 6) {

                            Text(app.name)
                                .font(.title2.bold())
                                .lineLimit(2)

                            Text(app.category)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            installButton
                        }

                        Spacer(minLength: 0)
                    }

                    // معلومات سريعة
                    HStack(spacing: 0) {

                        infoItem(title: .localized("الإصدار"), value: app.version)

                        Divider().frame(height: 34)

                        infoItem(
                            title: .localized("الحجم"),
                            value: app.sizeText ?? "—"
                        )

                        Divider().frame(height: 34)

                        infoItem(title: .localized("الفئة"), value: app.category)
                    }
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )

                    // الوصف
                    if !app.appDescription.isEmpty {

                        VStack(alignment: .leading, spacing: 8) {

                            Text(.localized("الوصف"))
                                .font(.headline)

                            Text(app.appDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // معرّف الحزمة
                    VStack(alignment: .leading, spacing: 8) {

                        Text(.localized("معرّف الحزمة"))
                            .font(.headline)

                        Text(app.bundleId)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(.localized("إغلاق")) {
                        dismiss()
                    }
                }
            }
        }
        .onReceive(downloadManager.$downloads) { downloads in
            guard let activeDownloadID else { return }
            if downloads.contains(where: { $0.id == activeDownloadID }) == false {
                self.activeDownloadID = nil
            }
        }
    }

    // MARK: Install Button

    private var installButton: some View {

        Button {
            install()
        } label: {

            Group {
                if activeDownloadID != nil {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(.localized("تثبيت"))
                        .font(.subheadline.weight(.bold))
                }
            }
            .frame(minWidth: 92)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Capsule().fill(Color.accentColor))
            .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(activeDownloadID != nil)
    }

    private func infoItem(title: String, value: String) -> some View {

        VStack(spacing: 4) {

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "—" : value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
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
        let download = downloadManager.startDownload(
            from: url,
            id: downloadID
        )

        activeDownloadID = download.id
        onDownloadStarted(download)
    }
}
