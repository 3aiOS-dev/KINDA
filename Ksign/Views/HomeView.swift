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

struct HomeView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var storeManager = KindaStoreManager.shared

    @State private var searchText = ""
    @State private var selectedAppID: String?
    @FocusState private var searchFieldFocused: Bool

    @State private var activeDownloads: [String: String] = [:]
    @State private var downloadWatchTasks: [String: Task<Void, Never>] = [:]
    @State private var downloadProgress: [String: Double] = [:]

    @FetchRequest(
        entity: Imported.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Imported.date, ascending: false)
        ],
        animation: .snappy
    )
    private var importedApps: FetchedResults<Imported>

    private var visibleApps: [StoreApp] {
        storeManager.filtered(searchText)
    }

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

    private var searchBar: some View {
        HStack(spacing: 8) {
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)

            Text(storeManager.errorMessage ?? (searchText.isEmpty ? "لا توجد تطبيقات بعد" : "لا توجد نتائج"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Text(
                storeManager.errorMessage == nil
                    ? (searchText.isEmpty
                        ? "أضف تطبيقاً من لوحة التحكم ليظهر هنا مباشرة."
                        : "جرّب البحث باسم التطبيق أو Bundle ID.")
                    : "تحقق من اتصال لوحة التحكم وصلاحيات Supabase ثم اضغط إعادة المحاولة."
            )
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if storeManager.errorMessage != nil || storeManager.apps.isEmpty {
                Button {
                    Task { await storeManager.load() }
                } label: {
                    HStack(spacing: 6) {
                        if storeManager.isLoading { ProgressView().controlSize(.small) }
                        Text(storeManager.isLoading ? "جاري المحاولة..." : "إعادة المحاولة")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(storeManager.isLoading)
            }
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
                        .multilineTextAlignment(.trailing)
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

    private func isDownloading(_ app: StoreApp) -> Bool {
        activeDownloads[app.id] != nil
    }

    private func install(_ app: StoreApp) {
        playInstallSound()
        startStoreDownload(for: app)
    }

    private func playInstallSound() {
        AudioServicesPlaySystemSound(1104)
    }

    private func repeatDownload(_ app: StoreApp) {
        startStoreDownload(for: app)
    }

    private func startStoreDownload(for app: StoreApp) {
        guard !isDownloading(app) else { return }

        let rawURL = app.ipaURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let decodedURL = rawURL.removingPercentEncoding ?? rawURL

        guard let url = URL(string: decodedURL),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized("The IPA URL is invalid.")
            )
            return
        }

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

extension HomeView {
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

            if let identifier = imported.identifier,
               !app.bundleId.isEmpty,
               identifier.caseInsensitiveCompare(app.bundleId) == .orderedSame {
                return true
            }

            if let name = imported.name,
               let version = imported.version,
               !app.version.isEmpty,
               name.localizedCaseInsensitiveCompare(app.name) == .orderedSame,
               version.caseInsensitiveCompare(app.version) == .orderedSame {
                return true
            }

            if let name = imported.name {
                return name.localizedCaseInsensitiveCompare(app.name) == .orderedSame
            }

            return false
        }
    }

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

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ksign.openLibraryTab"),
                object: nil
            )
        }
    }
}

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
        case id, name, title, version
        case bundleId, bundle_id, bundleID, identifier
        case appDescription, description
        case category
        case iconURL, icon_url, icon
        case ipaURL, ipa_url, ipa, downloadURL, download_url, download
        case sizeMB, size_mb, size
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func string(_ keys: CodingKeys...) -> String {
            for key in keys {
                if let value = try? c.decode(String.self, forKey: key),
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value
                }
                if let value = try? c.decode(URL.self, forKey: key) {
                    return value.absoluteString
                }
                if let value = try? c.decode(Int.self, forKey: key) {
                    return String(value)
                }
                if let value = try? c.decode(Double.self, forKey: key) {
                    return String(value)
                }
            }
            return ""
        }

        func double(_ keys: CodingKeys...) -> Double? {
            for key in keys {
                if let value = try? c.decode(Double.self, forKey: key) { return value }
                if let value = try? c.decode(Int.self, forKey: key) { return Double(value) }
                if let value = try? c.decode(String.self, forKey: key),
                   let parsed = Double(value.replacingOccurrences(of: ",", with: ".")) {
                    return parsed
                }
            }
            return nil
        }

        let rawID = string(.id)
        let rawName = string(.name, .title)
        let rawBundle = string(.bundleId, .bundle_id, .bundleID, .identifier)

        id = rawID.isEmpty
            ? (rawBundle.isEmpty ? (rawName.isEmpty ? UUID().uuidString : rawName) : rawBundle)
            : rawID
        name = rawName.isEmpty ? "تطبيق" : rawName
        version = string(.version)
        bundleId = rawBundle
        appDescription = string(.appDescription, .description)
        category = string(.category)
        iconURL = string(.iconURL, .icon_url, .icon)
        ipaURL = string(.ipaURL, .ipa_url, .ipa, .downloadURL, .download_url, .download)
        sizeMB = double(.sizeMB, .size_mb, .size)
    }

    var sizeText: String? {
        guard let sizeMB, sizeMB > 0 else { return nil }
        if sizeMB >= 1024 { return String(format: "%.2f GB", sizeMB / 1024) }
        return String(format: "%.0f MB", sizeMB)
    }

    var sizeValueText: String {
        guard let sizeMB, sizeMB > 0 else { return "—" }
        return String(format: "%.1f MB", sizeMB)
    }

    var shortIdentifier: String {
        bundleId.split(separator: ".").last.map(String.init) ?? bundleId
    }
}


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
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.bundleId.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var components = URLComponents(
            string: "\(baseURL)/rest/v1/store_apps"
        )
        components?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "1000")
        ]

        guard let url = components?.url else {
            errorMessage = "رابط لوحة التحكم غير صالح."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        // Supabase REST accepts the publishable/anon key as the bearer token too.
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw StoreError.invalidResponse
            }

            guard (200...299).contains(http.statusCode) else {
                let serverText = String(data: data, encoding: .utf8) ?? ""
                throw StoreError.http(http.statusCode, serverText)
            }

            guard !data.isEmpty else {
                apps = []
                errorMessage = "لوحة التحكم أعادت بيانات فارغة."
                return
            }

            do {
                let decoded = try JSONDecoder().decode([StoreApp].self, from: data)
                apps = decoded
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? ""
                throw StoreError.decode(error.localizedDescription, raw)
            }

            if apps.isEmpty {
                errorMessage = "الاتصال بلوحة التحكم ناجح، لكن لا توجد تطبيقات في store_apps."
            } else {
                errorMessage = nil
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            print("KINDA store error:", error)
        }
    }

    private enum StoreError: LocalizedError {
        case invalidResponse
        case http(Int, String)
        case decode(String, String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "استجابة لوحة التحكم غير صالحة."
            case .http(let status, let body):
                let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.isEmpty { return "لوحة التحكم أعادت HTTP \(status)." }
                return "لوحة التحكم أعادت HTTP \(status): \(clean.prefix(220))"
            case .decode(let message, _):
                return "تعذر قراءة بيانات التطبيقات: \(message)"
            }
        }
    }
}


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
