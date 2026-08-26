//
// HomeView.swift
// KINDA
//
// تطبيقات لوحة التحكم + البحث + تنزيل IPA.
//

import SwiftUI
import CoreData
import NimbleViews
import AudioToolbox

struct HomeView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var storeManager = KindaStoreManager.shared

    @State private var searchText = ""
    @State private var selectedAppID: String?
    @FocusState private var searchFocused: Bool

    @State private var activeDownloads: [String: String] = [:]
    @State private var downloadProgress: [String: Double] = [:]
    @State private var watchTasks: [String: Task<Void, Never>] = [:]

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
                KindaTheme.pageBG.ignoresSafeArea()
                KindaGridBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        Section {
                            if storeManager.isLoading && storeManager.apps.isEmpty {
                                ProgressView("جاري تحميل التطبيقات...")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 50)
                            } else if visibleApps.isEmpty {
                                emptyState
                            } else {
                                ForEach(visibleApps) { app in
                                    if selectedAppID == app.id {
                                        expandedItem(app)
                                    } else {
                                        rowView(app)
                                    }
                                }

                                if storeManager.isLoading {
                                    ProgressView()
                                        .padding(.vertical, 16)
                                }
                            }
                        } header: {
                            VStack(spacing: 0) {
                                Text("الرئيسية")
                                    .font(.system(size: 19, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 18)
                                    .padding(.bottom, 10)

                                searchBar
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }
                            .background(KindaTheme.pageBG)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    await storeManager.load()
                }
                .scrollDismissesKeyboard(.immediately)
                .environment(\.layoutDirection, .rightToLeft)
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
            watchTasks.values.forEach { $0.cancel() }
            watchTasks.removeAll()
        }
        .alert(
            "خطأ",
            isPresented: Binding(
                get: { storeManager.errorMessage != nil },
                set: { if !$0 { storeManager.errorMessage = nil } }
            )
        ) {
            Button("حسناً", role: .cancel) {}
            Button("إعادة المحاولة") {
                Task { await storeManager.load() }
            }
        } message: {
            Text(storeManager.errorMessage ?? "")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("ألعاب وتطبيقات والمزيد", text: $searchText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)

            Button {
                if searchText.isEmpty {
                    searchFocused = true
                } else {
                    searchText = ""
                }
            } label: {
                Image(systemName: searchText.isEmpty
                      ? "magnifyingglass"
                      : "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "لا توجد تطبيقات" : "لا توجد نتائج")
                .font(.system(size: 15, weight: .semibold))

            if let error = storeManager.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("أضف تطبيقاً من لوحة التحكم ليظهر هنا.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button("إعادة المحاولة") {
                Task { await storeManager.load() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 45)
    }

    private func rowView(_ app: StoreApp) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    selectedAppID = app.id
                }
            } label: {
                HStack(spacing: 12) {
                    StoreIconView(urlString: app.iconURL, size: 44)

                    Text(app.name)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            installButton(app)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            KindaTheme.cardBG,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func installButton(_ app: StoreApp) -> some View {
        let loading = activeDownloads[app.id] != nil
        let value = downloadProgress[app.id] ?? 0

        return Button {
            install(app)
        } label: {
            HStack(spacing: 5) {
                if loading {
                    ProgressView().controlSize(.small)
                }
                Text(loading ? "\(Int(value * 100))%" : "تثبيت")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(KindaTheme.chipBG, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    private func expandedItem(_ app: StoreApp) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                GeometryReader { proxy in
                    AsyncImage(url: URL(string: app.iconURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.black
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 55)
                    .overlay(Color.black.opacity(0.48))
                    .clipped()
                }

                VStack(spacing: 14) {
                    StoreIconView(urlString: app.iconURL, size: 100)

                    Text(app.name)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Button {
                        install(app)
                    } label: {
                        HStack {
                            if activeDownloads[app.id] != nil {
                                ProgressView().tint(.white)
                            }
                            Text(activeDownloads[app.id] == nil ? "تثبيت" : "جاري التثبيت")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 42)
                        .background(.white.opacity(0.22), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(activeDownloads[app.id] != nil)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 35)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedAppID = nil
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(12)
            }
            .frame(height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            HStack(spacing: 8) {
                stat(title: "الإصدار", value: app.version)
                stat(title: "الحجم", value: app.sizeText ?? "—")
            }
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func install(_ app: StoreApp) {
        guard activeDownloads[app.id] == nil else { return }

        guard
            let url = URL(string: app.ipaURL.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            storeManager.errorMessage = "رابط IPA للتطبيق غير صالح."
            return
        }

        AudioServicesPlaySystemSound(1104)

        let id = "KindaStore_\(app.id)_\(UUID().uuidString)"
        let download = downloadManager.startDownload(from: url, id: id)

        activeDownloads[app.id] = download.id
        downloadProgress[app.id] = 0
        watch(download: download, app: app)
    }

    private func watch(download: Download, app: StoreApp) {
        watchTasks[download.id]?.cancel()

        let task = Task { @MainActor in
            let deadline = Date().addingTimeInterval(15 * 60)

            while !Task.isCancelled && Date() < deadline {
                if let current = downloadManager.getDownload(by: download.id) {
                    downloadProgress[app.id] = current.progress

                    if current.progress >= 0.999 {
                        try? await Task.sleep(for: .milliseconds(500))
                        finish(app)
                        return
                    }
                } else {
                    // DownloadManager may remove completed downloads after
                    // handing the file to the library.
                    if findImported(app) != nil {
                        finish(app)
                        return
                    }
                }

                if findImported(app) != nil {
                    finish(app)
                    return
                }

                try? await Task.sleep(for: .milliseconds(250))
            }

            guard !Task.isCancelled else { return }

            if findImported(app) != nil {
                finish(app)
            } else {
                activeDownloads[app.id] = nil
                downloadProgress[app.id] = nil
                watchTasks[download.id] = nil
                storeManager.errorMessage = "انتهى وقت تنزيل أو استيراد \(app.name)."
            }
        }

        watchTasks[download.id] = task
    }

    private func findImported(_ app: StoreApp) -> Imported? {
        importedApps.first { item in
            if let identifier = item.identifier,
               !app.bundleId.isEmpty,
               identifier.caseInsensitiveCompare(app.bundleId) == .orderedSame {
                return true
            }

            if let name = item.name,
               name.localizedCaseInsensitiveCompare(app.name) == .orderedSame {
                return true
            }

            return false
        }
    }

    private func finish(_ app: StoreApp) {
        activeDownloads[app.id] = nil
        downloadProgress[app.id] = nil

        if let id = activeDownloads[app.id] {
            watchTasks[id] = nil
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("ksign.openLibraryTab"),
            object: nil
        )
    }
}

// MARK: - Models

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
        case bundleId = "bundle_id"
        case bundleID
        case identifier
        case appDescription = "description"
        case category
        case iconURL = "icon_url"
        case icon
        case ipaURL = "ipa_url"
        case ipa
        case downloadURL = "download_url"
        case download
        case sizeMB = "size_mb"
        case size
    }

    init(
        id: String,
        name: String,
        version: String,
        bundleId: String,
        appDescription: String,
        category: String,
        iconURL: String,
        ipaURL: String,
        sizeMB: Double?
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.bundleId = bundleId
        self.appDescription = appDescription
        self.category = category
        self.iconURL = iconURL
        self.ipaURL = ipaURL
        self.sizeMB = sizeMB
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func text(_ keys: CodingKeys...) -> String {
            for key in keys {
                if let v = try? c.decode(String.self, forKey: key), !v.isEmpty {
                    return v
                }
                if let v = try? c.decode(Int.self, forKey: key) {
                    return String(v)
                }
                if let v = try? c.decode(Double.self, forKey: key) {
                    return String(v)
                }
            }
            return ""
        }

        func number(_ keys: CodingKeys...) -> Double? {
            for key in keys {
                if let v = try? c.decode(Double.self, forKey: key) { return v }
                if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
                if let v = try? c.decode(String.self, forKey: key) {
                    return Double(v.replacingOccurrences(of: ",", with: "."))
                }
            }
            return nil
        }

        let rawID = text(.id)
        let rawName = text(.name, .title)
        let rawBundle = text(.bundleId, .bundleID, .identifier)
        let rawIPA = text(.ipaURL, .ipa, .downloadURL, .download)
        let rawIcon = text(.iconURL, .icon)

        id = rawID.isEmpty
            ? (rawBundle.isEmpty ? (rawName.isEmpty ? UUID().uuidString : rawName) : rawBundle)
            : rawID

        name = rawName.isEmpty ? "تطبيق" : rawName
        version = text(.version)
        bundleId = rawBundle
        appDescription = text(.appDescription)
        category = text(.category)
        iconURL = rawIcon
        ipaURL = rawIPA
        sizeMB = number(.sizeMB, .size)
    }

    var sizeText: String? {
        guard let sizeMB, sizeMB > 0 else { return nil }
        return sizeMB >= 1024
            ? String(format: "%.2f GB", sizeMB / 1024)
            : String(format: "%.0f MB", sizeMB)
    }
}

// MARK: - Supabase dashboard manager

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
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return apps }

        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.bundleId.localizedCaseInsensitiveContains(q) ||
            $0.category.localizedCaseInsensitiveContains(q)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard var components = URLComponents(
            string: "\(baseURL)/rest/v1/store_apps"
        ) else {
            errorMessage = "رابط قاعدة البيانات غير صالح."
            return
        }

        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components.url else {
            errorMessage = "تعذر إنشاء رابط قاعدة البيانات."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData

        // Supabase REST requires the API key. Authorization is also supplied
        // so projects using JWT-style gateway policies work correctly.
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw StoreError.invalidResponse
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw StoreError.http(http.statusCode, body)
            }

            let decoder = JSONDecoder()

            guard let decoded = try? decoder.decode([StoreApp].self, from: data) else {
                throw StoreError.invalidJSON(
                    String(data: data, encoding: .utf8) ?? ""
                )
            }

            apps = decoded.filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        } catch {
            apps = []
            errorMessage = error.localizedDescription
        }
    }

    private enum StoreError: LocalizedError {
        case invalidResponse
        case http(Int, String)
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "استجابة لوحة التحكم غير صالحة."
            case .http(let code, let body):
                if body.isEmpty {
                    return "لوحة التحكم أعادت HTTP \(code)."
                }
                return "لوحة التحكم أعادت HTTP \(code): \(body)"
            case .invalidJSON(let body):
                return "بيانات لوحة التحكم ليست JSON صالحاً.\n\(body)"
            }
        }
    }
}

// MARK: - Icon

struct StoreIconView: View {
    let urlString: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url = URL(string: urlString),
               !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
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
    }

    private var placeholder: some View {
        RoundedRectangle(
            cornerRadius: size / 4.5,
            style: .continuous
        )
        .fill(Color.secondary.opacity(0.12))
        .overlay {
            Image(systemName: "app.fill")
                .font(.system(size: size / 3))
                .foregroundStyle(.secondary)
        }
    }
}
