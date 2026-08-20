//
//  HomeView.swift
//  Ksign
//
//  التطبيقات — قائمة + بطاقة موسّعة، مطابقة للتصميم في الصور
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - Theme

enum KindaTheme {

    static let purple = Color(red: 0.35, green: 0.20, blue: 0.95)
    static let purpleLight = Color(red: 0.58, green: 0.42, blue: 0.98)

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
    @State private var selectedAppID: String?

    // تنزيلات المتجر التي تنتظر اكتمال الاستيراد إلى المكتبة
    @State private var activeDownloads: [String: String] = [:] // appID -> downloadID
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

    private var visibleApps: [StoreApp] {
        storeManager.filtered(searchText)
    }

    // MARK: Body

    var body: some View {

        ZStack(alignment: .top) {

            KindaTheme.pageBG.ignoresSafeArea()

            VStack(spacing: 0) {

                titleHeader
                searchBar

                ScrollView(showsIndicators: false) {

                    LazyVStack(spacing: 14) {

                        ForEach(visibleApps) { app in

                            if selectedAppID == app.id {
                                expandedItem(app)
                            } else {
                                rowView(app)
                            }
                        }
                    }
                    .padding(.top, 10)
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
        .onDisappear {
            for task in downloadWatchTasks.values { task.cancel() }
            downloadWatchTasks.removeAll()
        }
    }

    // MARK: Title

    private var titleHeader: some View {

        Text("التطبيقات")
            .font(.system(size: 34, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    // MARK: Search

    private var searchBar: some View {

        HStack(spacing: 10) {

            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("ألعاب وتطبيقات والمزيد", text: $searchText)
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

    // MARK: Collapsed Row

    private func rowView(_ app: StoreApp) -> some View {

        HStack(spacing: 14) {

            HStack(spacing: 14) {

                StoreIconView(urlString: app.iconURL, size: 56)

                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) { selectedAppID = app.id }
            }

            Spacer(minLength: 8)

            Button {
                install(app)
            } label: {

                Group {
                    if isDownloading(app) {
                        ProgressView()
                            .tint(.primary)
                            .frame(width: 30)
                    } else {
                        Text("تثبيت")
                            .font(.subheadline.weight(.bold))
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(isDownloading(app))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(KindaTheme.cardBG)
        )
        .padding(.horizontal, 16)
    }

    // MARK: Expanded Item (Row + Card + Stats)

    private func expandedItem(_ app: StoreApp) -> some View {

        VStack(spacing: 10) {

            ZStack(alignment: .topTrailing) {

                expandedCard(app)

                collapseButton
                    .padding(.top, -28)
                    .padding(.trailing, 28)
            }

            statsRow(app)
        }
        .padding(.horizontal, 16)
    }

    private var collapseButton: some View {

        Button {
            withAnimation(.snappy) { selectedAppID = nil }
        } label: {

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.primary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.white))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Expanded Card (blurred icon background)

    private func expandedCard(_ app: StoreApp) -> some View {

        ZStack {

            GeometryReader { proxy in

                AsyncImage(url: URL(string: app.iconURL)) { image in

                    image
                        .resizable()
                        .scaledToFill()

                } placeholder: {
                    Color.black
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .blur(radius: 60)
                .overlay(Color.black.opacity(0.45))
                .clipped()
            }

            VStack(spacing: 18) {

                StoreIconView(urlString: app.iconURL, size: 150)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 10)

                Text(app.name)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                if !app.appDescription.isEmpty {
                    Text(app.appDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }

                if !app.category.isEmpty || !app.bundleId.isEmpty {
                    HStack(spacing: 8) {
                        if !app.category.isEmpty {
                            Text(app.category)
                        }

                        if !app.category.isEmpty && !app.bundleId.isEmpty {
                            Text("•")
                        }

                        if !app.bundleId.isEmpty {
                            Text(app.bundleId)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.72))
                }

                HStack(spacing: 12) {

                    pillButton(title: "تكرار", isLoading: isDownloading(app)) {
                        repeatDownload(app)
                    }

                    pillButton(title: "تثبيت", isLoading: isDownloading(app)) {
                        install(app)
                    }
                }
            }
            .padding(.vertical, 46)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 380)
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
    }

    private func pillButton(title: String, isLoading: Bool = false, action: @escaping () -> Void) -> some View {

        Button(action: action) {

            HStack(spacing: 8) {

                if isLoading {
                    ProgressView().tint(Color.white)
                }

                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.white.opacity(0.22)))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: Stats Row (حجم التطبيق / الإصدار)

    private func statsRow(_ app: StoreApp) -> some View {

        HStack(spacing: 12) {

            statBox(title: "حجم التطبيق", value: app.sizeValueText)
            statBox(title: "الإصدار", value: app.version)
        }
    }

    private func statBox(title: String, value: String) -> some View {

        VStack(spacing: 6) {

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "—" : value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: Downloads

    private func isDownloading(_ app: StoreApp) -> Bool {
        activeDownloads[app.id] != nil
    }

    private func install(_ app: StoreApp) {
        startStoreDownload(for: app)
    }

    /// إعادة التنزيل من رابط IPA الحقيقي الموجود في المتجر.
    /// هذه هي وظيفة زر «تكرار»: تبدأ عملية تنزيل واستيراد جديدة فعلياً.
    private func repeatDownload(_ app: StoreApp) {
        startStoreDownload(for: app)
    }

    private func startStoreDownload(for app: StoreApp) {

        guard !isDownloading(app) else { return }

        guard
            let url = URL(string: app.ipaURL.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized("The IPA URL is invalid.")
            )
            return
        }

        // UUIDs الموجودة قبل التنزيل. بهذا لا نعتبر نسخة قديمة
        // موجودة في المكتبة نجاحاً للمحاولة الجديدة.
        let existingImportedUUIDs = Set(
            importedApps.compactMap { $0.uuid }
        )

        let startedAt = Date()

        // ID مختلف لكل محاولة، حتى يعمل «تكرار» فعلياً.
        let downloadID = "KindaStore_\(app.id)_\(UUID().uuidString)"

        let download = downloadManager.startDownload(
            from: url,
            id: downloadID
        )

        activeDownloads[app.id] = download.id

        watchStoreDownload(
            download,
            app: app,
            existingImportedUUIDs: existingImportedUUIDs,
            startedAt: startedAt
        )
    }
}

// MARK: - Store Download Handling

extension HomeView {

    /// ينتظر اكتمال تنزيل IPA ثم اكتمال استيراده فعلياً إلى Core Data.
    /// اختفاء Download من DownloadManager لا يعني فشلاً؛ لأن المدير قد
    /// يحذف عنصر التنزيل بعد تسليم الملف إلى FR.handlePackageFile.
    private func watchStoreDownload(
        _ download: Download,
        app: StoreApp,
        existingImportedUUIDs: Set<String>,
        startedAt: Date
    ) {

        let downloadID = download.id

        downloadWatchTasks[downloadID]?.cancel()

        let task = Task { @MainActor in

            // 15 دقيقة كحد أقصى لملفات IPA الكبيرة أو الاتصالات البطيئة.
            let timeout: UInt64 = 15 * 60 * 1_000_000_000
            let pollInterval: UInt64 = 300_000_000
            let deadline = DispatchTime.now().uptimeNanoseconds + timeout

            var reachedDownloadCompletion = false

            while !Task.isCancelled {

                // معيار النجاح الحقيقي: ظهور Imported جديد لهذه المحاولة.
                if let imported = findNewImportedApp(
                    for: app,
                    existingUUIDs: existingImportedUUIDs,
                    startedAt: startedAt
                ) {
                    finishStoreDownload(
                        app: app,
                        downloadID: downloadID,
                        success: true,
                        imported: imported
                    )
                    return
                }

                if let currentDownload = DownloadManager.shared.getDownload(
                    by: downloadID
                ) {
                    if currentDownload.totalBytes > 0,
                       currentDownload.progress >= 0.999 {
                        reachedDownloadCompletion = true
                    }
                } else if reachedDownloadCompletion {
                    // التنزيل انتهى، لكن الاستيراد قد يحتاج وقتاً.
                    // نستمر بالمراقبة بدلاً من عرض خطأ كاذب.
                }

                if DispatchTime.now().uptimeNanoseconds >= deadline {
                    break
                }

                try? await Task.sleep(nanoseconds: pollInterval)
            }

            guard !Task.isCancelled else { return }

            // فحص نهائي بعد انتهاء التنزيل/المعالجة.
            if let imported = findNewImportedApp(
                for: app,
                existingUUIDs: existingImportedUUIDs,
                startedAt: startedAt
            ) {
                finishStoreDownload(
                    app: app,
                    downloadID: downloadID,
                    success: true,
                    imported: imported
                )
                return
            }

            finishStoreDownload(
                app: app,
                downloadID: downloadID,
                success: false,
                imported: nil
            )
        }

        downloadWatchTasks[downloadID] = task
    }

    /// يبحث عن سجل Imported جديد ناتج عن محاولة التنزيل الحالية.
    private func findNewImportedApp(
        for app: StoreApp,
        existingUUIDs: Set<String>,
        startedAt: Date
    ) -> Imported? {

        importedApps.first { imported in

            guard
                let uuid = imported.uuid,
                !existingUUIDs.contains(uuid)
            else {
                return false
            }

            if let date = imported.date,
               date < startedAt.addingTimeInterval(-2) {
                return false
            }

            // Bundle ID هو المطابقة الأقوى.
            if let identifier = imported.identifier,
               !app.bundleId.isEmpty,
               identifier.caseInsensitiveCompare(app.bundleId) == .orderedSame {
                return true
            }

            // ثم الاسم + الإصدار.
            if let name = imported.name,
               let version = imported.version,
               !app.version.isEmpty,
               name.localizedCaseInsensitiveCompare(app.name) == .orderedSame,
               version.caseInsensitiveCompare(app.version) == .orderedSame {
                return true
            }

            // وأخيراً الاسم وحده كحل احتياطي.
            if let name = imported.name {
                return name.localizedCaseInsensitiveCompare(app.name) == .orderedSame
            }

            return false
        }
    }

    /// ينظف حالة التنزيل ولا يفتح المكتبة إلا بعد نجاح الاستيراد الحقيقي.
    private func finishStoreDownload(
        app: StoreApp,
        downloadID: String,
        success: Bool,
        imported: Imported?
    ) {

        activeDownloads[app.id] = nil
        downloadWatchTasks[downloadID] = nil

        guard success, imported != nil else {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized(
                    "The IPA download or import could not be completed."
                )
            )
            return
        }

        // التطبيق أصبح Imported فعلياً؛ الآن افتح المكتبة.
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ksign.openLibraryTab"),
                object: nil
            )
        }
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

    /// رقم الحجم فقط بمنزلة عشرية واحدة (لبطاقة الإحصائيات)، بدون وحدة.
    var sizeValueText: String {

        guard let sizeMB, sizeMB > 0 else { return "—" }
        return String(format: "%.1f", sizeMB)
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
