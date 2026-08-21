import SwiftUI
import CoreData
import NimbleViews
import AudioToolbox


enum KindaTheme {
    static let purple = Color(red: 0.35, green: 0.20, blue: 0.95)
    static let purpleLight = Color(red: 0.58, green: 0.42, blue: 0.98)

    static var cardBG: Color { Color(.secondarySystemGroupedBackground) }
    static var pageBG: Color { Color(.systemBackground) }
    static var chipBG: Color { Color.secondary.opacity(0.12) }
}

/// خلفية شبكية خفيفة مشابهة لتصميم المتجر في الصورة.
struct KindaGridBackground: View {
    private let spacing: CGFloat = 48
    private let lineOpacity: Double = 0.045

    var body: some View {
        Canvas { context, size in
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(
                path,
                with: .color(.primary.opacity(lineOpacity)),
                lineWidth: 0.7
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Home View

struct HomeView: View {
    // MARK: Managers
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var storeManager = KindaStoreManager.shared

    // MARK: State
    @State private var searchText = ""
    @State private var selectedAppID: String?
    @FocusState private var searchFieldFocused: Bool

    // تنزيلات المتجر التي تنتظر اكتمال الاستيراد إلى المكتبة.
    @State private var activeDownloads: [String: String] = [:]
    @State private var downloadWatchTasks: [String: Task<Void, Never>] = [:]
    @State private var downloadProgress: [String: Double] = [:]

    // MARK: Core Data
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
        NavigationStack {
            ZStack {
                KindaTheme.pageBG
                    .ignoresSafeArea()

                KindaGridBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            if visibleApps.isEmpty {
                                emptyState
                                    .padding(.horizontal, 16)
                                    .padding(.top, 24)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(visibleApps) { app in
                                        if selectedAppID == app.id {
                                            expandedItem(app)
                                        } else {
                                            rowView(app)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 6)
                            }
                        } header: {
                            VStack(spacing: 0) {
                                titleHeader

                                searchBar
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .background(KindaTheme.pageBG)
                            .zIndex(2)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .environment(\.layoutDirection, .rightToLeft)
                .refreshable {
                    await storeManager.load()
                }

            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            if storeManager.apps.isEmpty {
                await storeManager.load()
            }
        }
        .onDisappear {
            for task in downloadWatchTasks.values {
                task.cancel()
            }
            downloadWatchTasks.removeAll()
        }
    }

    // MARK: Title
    private var titleHeader: some View {
        Text("الرئيسية")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .multilineTextAlignment(.center)
    }

    // MARK: Search
    private var searchBar: some View {
        HStack(spacing: 8) {
            // نحافظ على ترتيب التصميم بصرياً داخل RTL.
            TextField("", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($searchFieldFocused)
                .onSubmit {
                    searchFieldFocused = false
                }
                .overlay(alignment: .trailing) {
                    if searchText.isEmpty {
                        Text("ألعاب وتطبيقات والمزيد")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.65))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .allowsHitTesting(false)
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    searchFieldFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    // MARK: Empty State
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "لا توجد تطبيقات بعد" : "لا توجد نتائج")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Text(
                searchText.isEmpty
                    ? "أضف تطبيقاً من لوحة التحكم ليظهر هنا مباشرة."
                    : "جرّب البحث باسم التطبيق أو Bundle ID."
            )
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    // MARK: Collapsed Row
    /// صف مطابق تماماً لتصميم بطاقة "Cinemana" المرجعية: أيقونة + اسم فقط +
    /// زر تثبيت، وخلفه بطاقة خفيفة بسيطة بدون أي تفاصيل إضافية.
    private func rowView(_ app: StoreApp) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    selectedAppID = app.id
                }
            } label: {
                HStack(spacing: 12) {
                    StoreIconView(urlString: app.iconURL, size: 44)

                    Text(app.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            getButton(app)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: Primary Get / Install Button
    private func getButton(_ app: StoreApp) -> some View {
        let loading = isDownloading(app)
        let progress = downloadProgress[app.id] ?? 0

        return Button {
            install(app)
        } label: {
            HStack(spacing: 5) {
                if loading {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 2)
                            .frame(width: 14, height: 14)

                        Circle()
                            .trim(from: 0, to: max(0.03, progress))
                            .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 14, height: 14)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: progress)
                    }
                }

                Text(loading ? "\(Int(progress * 100))%" : "تثبيت")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color.secondary.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    // MARK: Expanded Item
    private func expandedItem(_ app: StoreApp) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                expandedCard(app)

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedAppID = nil
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.leading, 12)
            }

            statsRow(app)
        }
    }

    // MARK: Expanded Card
    private func expandedCard(_ app: StoreApp) -> some View {
        ZStack {
            GeometryReader { proxy in
                AsyncImage(url: URL(string: app.iconURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.black)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .blur(radius: 58)
                .overlay(Color.black.opacity(0.46))
                .clipped()
            }

            // طبقة زجاجية خفيفة فوق الخلفية الضبابية.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.20)

            VStack(spacing: 16) {
                StoreIconView(urlString: app.iconURL, size: 108)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 10)

                Text(app.name)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    pillButton(
                        title: "تكرار",
                        isLoading: isDownloading(app)
                    ) {
                        repeatDownload(app)
                    }

                    pillButton(
                        title: "تثبيت",
                        isLoading: isDownloading(app)
                    ) {
                        install(app)
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.vertical, 34)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        }
    }

    private func pillButton(
        title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }

                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(height: 44)
            .background(Color.white.opacity(0.22), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: Stats
    private func statsRow(_ app: StoreApp) -> some View {
        HStack(spacing: 8) {
            statBox(title: "حجم التطبيق", value: app.sizeValueText)
            statBox(title: "الإصدار", value: app.version)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 104, height: 46)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.6)
        }
    }

    // MARK: Downloads
    private func isDownloading(_ app: StoreApp) -> Bool {
        activeDownloads[app.id] != nil
    }

    private func install(_ app: StoreApp) {
        playInstallSound()
        startStoreDownload(for: app)
    }

    /// نغمة نظام قصيرة عند الضغط على "تثبيت"، تماماً كسلوك المتجر الرسمي.
    private func playInstallSound() {
        AudioServicesPlaySystemSound(1104)
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

        // نلتقط السجلات الموجودة قبل بدء المحاولة حتى لا تعتبر نسخة قديمة نجاحاً.
        let existingImportedUUIDs = Set(
            importedApps.compactMap { $0.uuid }
        )

        let startedAt = Date()
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
    /// اختفاء Download من DownloadManager لا يعني فشلاً، لأن المدير قد يحذف
    /// عنصر التنزيل بعد تسليم الملف إلى معالجة الاستيراد.
    private func watchStoreDownload(
        _ download: Download,
        app: StoreApp,
        existingImportedUUIDs: Set<String>,
        startedAt: Date
    ) {
        let downloadID = download.id

        downloadWatchTasks[downloadID]?.cancel()

        let task = Task { @MainActor in
            let timeout: UInt64 = 15 * 60 * 1_000_000_000
            let pollInterval: UInt64 = 300_000_000
            let deadline = DispatchTime.now().uptimeNanoseconds + timeout

            var reachedDownloadCompletion = false

            while !Task.isCancelled {
                // النجاح الحقيقي هو ظهور Imported جديد ناتج عن المحاولة الحالية.
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

                if let currentDownload = DownloadManager.shared.getDownload(by: downloadID) {
                    downloadProgress[app.id] = currentDownload.progress

                    if currentDownload.totalBytes > 0,
                       currentDownload.progress >= 0.999 {
                        reachedDownloadCompletion = true
                    }
                } else if reachedDownloadCompletion {
                    // اكتمل التنزيل لكن الاستيراد قد يحتاج وقتاً إضافياً.
                    downloadProgress[app.id] = 1.0
                }

                if DispatchTime.now().uptimeNanoseconds >= deadline {
                    break
                }

                try? await Task.sleep(nanoseconds: pollInterval)
            }

            guard !Task.isCancelled else { return }

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

            // وأخيراً الاسم كحل احتياطي.
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
        downloadProgress[app.id] = nil

        guard success, imported != nil else {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized(
                    "The IPA download or import could not be completed."
                )
            )
            return
        }

        // أصبح التطبيق Imported فعلياً؛ افتح المكتبة بعد نجاح الاستيراد فقط.
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

    /// نص الحجم جاهز للعرض (MB أو GB).
    var sizeText: String? {
        guard let sizeMB, sizeMB > 0 else { return nil }

        if sizeMB >= 1024 {
            return String(format: "%.2f GB", sizeMB / 1024)
        }

        return String(format: "%.0f MB", sizeMB)
    }

    /// رقم الحجم فقط بمنزلة عشرية واحدة لبطاقة الإحصائيات.
    var sizeValueText: String {
        guard let sizeMB, sizeMB > 0 else { return "—" }
        return String(format: "%.1f", sizeMB)
    }

    /// معرّف مختصر.
    var shortIdentifier: String {
        bundleId.split(separator: ".").last.map(String.init) ?? bundleId
    }
}

// MARK: - Store Manager

@MainActor
final class KindaStoreManager: ObservableObject {
    static let shared = KindaStoreManager()

    // بيانات الاتصال بلوحة التحكم (Lovable Cloud).
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

        defer {
            isLoading = false
        }

        guard let url = URL(
            string: "\(baseURL)/rest/v1/store_apps?select=*&order=created_at.desc"
        ) else {
            errorMessage = "Invalid store URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
            }

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
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .failure:
                placeholder

            case .empty:
                placeholder

            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: size / 4.5,
                style: .continuous
            )
        )
        .contentShape(Rectangle())
    }

    private var placeholder: some View {
        RoundedRectangle(
            cornerRadius: size / 4.5,
            style: .continuous
        )
        .fill(Color.secondary.opacity(0.15))
        .overlay {
            Image(systemName: "app.dashed")
                .font(.system(size: size / 3, weight: .light))
                .foregroundStyle(.secondary)
        }
    }
}
