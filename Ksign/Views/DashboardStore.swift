//
// DashboardStore.swift
// KINDA
//

import Foundation
import SwiftUI

struct StoreApp: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let version: String
    let bundleIdentifier: String
    let iconURL: String
    let ipaURL: String
    let category: String

    enum CodingKeys: String, CodingKey {
        case id, name, title, version
        case bundleIdentifier, bundleID, identifier
        case iconURL, icon
        case ipaURL, ipa, downloadURL, download
        case category
    }

    init(
        id: String,
        name: String,
        version: String,
        bundleIdentifier: String,
        iconURL: String,
        ipaURL: String,
        category: String
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.bundleIdentifier = bundleIdentifier
        self.iconURL = iconURL
        self.ipaURL = ipaURL
        self.category = category
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
            }
            return ""
        }

        let rawID = string(.id)
        let rawName = string(.name, .title)
        let rawVersion = string(.version)
        let rawBundle = string(.bundleIdentifier, .bundleID, .identifier)
        let rawIcon = string(.iconURL, .icon)
        let rawIPA = string(.ipaURL, .ipa, .downloadURL, .download)
        let rawCategory = string(.category)

        id = rawID.isEmpty
            ? (rawBundle.isEmpty ? (rawName.isEmpty ? UUID().uuidString : rawName) : rawBundle)
            : rawID

        name = rawName.isEmpty ? "تطبيق" : rawName
        version = rawVersion
        bundleIdentifier = rawBundle
        iconURL = rawIcon
        ipaURL = rawIPA
        category = rawCategory
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(version, forKey: .version)
        try c.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try c.encode(iconURL, forKey: .iconURL)
        try c.encode(ipaURL, forKey: .ipaURL)
        try c.encode(category, forKey: .category)
    }
}

@MainActor
final class KindaStoreManager: ObservableObject {
    static let shared = KindaStoreManager()

    private var controlPanelAppsURL: String {
        UserDefaults.standard.string(forKey: "kinda.controlPanelAppsURL")
            ?? "https://portal.kinda.app/api/apps"
    }

    @Published private(set) var apps: [StoreApp] = []
    @Published private(set) var categories: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var hasMorePages = false

    private var currentPage = 1
    private let pageSize = 50

    private init() {}

    func reload() async {
        currentPage = 1
        lastError = nil
        hasMorePages = false
        await load(page: 1, replace: true)
    }

    func loadNextPage() async {
        guard !isLoading, hasMorePages else { return }
        await load(page: currentPage + 1, replace: false)
    }

    private func load(page: Int, replace: Bool) async {
        guard let base = URL(string: controlPanelAppsURL),
              let scheme = base.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            lastError = "رابط لوحة التحكم غير صالح."
            return
        }

        isLoading = true
        defer { isLoading = false }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        var query = components?.queryItems ?? []

        query.removeAll {
            $0.name == "page" || $0.name == "limit" || $0.name == "per_page"
        }

        query.append(URLQueryItem(name: "page", value: String(page)))
        query.append(URLQueryItem(name: "limit", value: String(pageSize)))
        components?.queryItems = query

        guard let url = components?.url else {
            lastError = "تعذر إنشاء رابط الطلب."
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 30
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw StoreError.invalidResponse
            }

            guard (200...299).contains(http.statusCode) else {
                throw StoreError.http(http.statusCode)
            }

            let result = try decode(data)

            if replace {
                apps = result.apps
            } else {
                var ids = Set(apps.map(\.id))
                for app in result.apps where !ids.contains(app.id) {
                    apps.append(app)
                    ids.insert(app.id)
                }
            }

            currentPage = page
            hasMorePages = result.hasMore || result.apps.count >= pageSize
            updateCategories()
            lastError = apps.isEmpty ? "لم تُرجع لوحة التحكم أي تطبيقات." : nil
        } catch {
            lastError = error.localizedDescription
            print("KINDA dashboard error:", error)
        }
    }

    private func updateCategories() {
        categories = Array(
            Set(apps.map(\.category).filter { !$0.isEmpty })
        ).sorted()
    }

    private struct Envelope: Decodable {
        let apps: [StoreApp]
        let hasMore: Bool

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)

            var result: [StoreApp] = []

            for key in ["apps", "items", "results", "data", "applications"] {
                guard let k = DynamicKey(stringValue: key) else { continue }

                if let value = try? c.decode([StoreApp].self, forKey: k) {
                    result = value
                    break
                }

                if let object = try? c.decode(ObjectEnvelope.self, forKey: k) {
                    result = object.apps
                    break
                }
            }

            apps = result

            let moreKey = DynamicKey(stringValue: "hasMore")!
            if let value = try? c.decode(Bool.self, forKey: moreKey) {
                hasMore = value
            } else if let value = try? c.decode(String.self, forKey: moreKey) {
                hasMore = ["true", "1", "yes"].contains(value.lowercased())
            } else {
                hasMore = false
            }
        }
    }

    private struct ObjectEnvelope: Decodable {
        let apps: [StoreApp]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            var result: [StoreApp] = []

            for key in ["apps", "items", "results", "data", "applications"] {
                guard let k = DynamicKey(stringValue: key) else { continue }
                if let value = try? c.decode([StoreApp].self, forKey: k) {
                    result = value
                    break
                }
            }

            apps = result
        }
    }

    private func decode(_ data: Data) throws -> (apps: [StoreApp], hasMore: Bool) {
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([StoreApp].self, from: data) {
            return (direct, false)
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        return (envelope.apps, envelope.hasMore)
    }

    private enum StoreError: LocalizedError {
        case invalidResponse
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "استجابة لوحة التحكم غير صالحة."
            case .http(let code):
                return "لوحة التحكم أعادت HTTP \(code)."
            }
        }
    }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct DashboardIconView: View {
    let urlString: String

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
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        Image(systemName: "app.fill")
            .font(.system(size: 24))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.10))
    }
}
