//
// DashboardStore.swift
// KINDA
//
// نوع البيانات ومدير تطبيقات لوحة التحكم.
// لا يستخدم أي مصادر خارجية.
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
        case id
        case name
        case title
        case version
        case bundleIdentifier
        case bundleID
        case identifier
        case iconURL
        case icon
        case ipaURL
        case ipa
        case downloadURL
        case download
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
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func string(_ keys: CodingKeys...) -> String {
            for key in keys {
                if let value = try? container.decode(String.self, forKey: key),
                   !value.isEmpty {
                    return value
                }
            }
            return ""
        }

        let decodedID = string(.id)
        let decodedName = string(.name, .title)
        let decodedVersion = string(.version)
        let decodedBundle = string(.bundleIdentifier, .bundleID, .identifier)
        let decodedIcon = string(.iconURL, .icon)
        let decodedIPA = string(.ipaURL, .ipa, .downloadURL, .download)
        let decodedCategory = string(.category)

        id = decodedID.isEmpty
            ? (decodedBundle.isEmpty ? decodedName : decodedBundle)
            : decodedID

        name = decodedName.isEmpty ? "تطبيق" : decodedName
        version = decodedVersion
        bundleIdentifier = decodedBundle
        iconURL = decodedIcon
        ipaURL = decodedIPA
        category = decodedCategory
    }

    // Xcode 26 / Swift 6:
    // CodingKeys تحتوي على مفاتيح بديلة للفك، لذلك يتم تعريف Encodable
    // بشكل صريح حتى لا يعتمد البناء على synthesis التلقائي.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(version, forKey: .version)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(iconURL, forKey: .iconURL)
        try container.encode(ipaURL, forKey: .ipaURL)
        try container.encode(category, forKey: .category)
    }
}

@MainActor
final class KindaStoreManager: ObservableObject {
    static let shared = KindaStoreManager()

    // Endpoint الخاص بلوحة التحكم فقط.
    // غيّره إذا كان endpoint JSON الفعلي للوحة التحكم مختلفاً.
    private let controlPanelAppsURL = "https://portal.kinda.app/api/apps"

    @Published private(set) var apps: [StoreApp] = []
    @Published private(set) var categories: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMorePages = false

    private var currentPage = 1
    private let pageSize = 50

    private init() {}

    func reload() async {
        currentPage = 1
        apps.removeAll()
        categories.removeAll()
        hasMorePages = false

        await loadPage(1, replacing: true)
    }

    func loadNextPage() async {
        guard !isLoading, hasMorePages else {
            return
        }

        await loadPage(currentPage + 1, replacing: false)
    }

    private func loadPage(_ page: Int, replacing: Bool) async {
        guard let base = URL(string: controlPanelAppsURL) else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        var components = URLComponents(
            url: base,
            resolvingAgainstBaseURL: false
        )

        var query = components?.queryItems ?? []

        query.append(
            URLQueryItem(
                name: "page",
                value: String(page)
            )
        )

        query.append(
            URLQueryItem(
                name: "limit",
                value: String(pageSize)
            )
        )

        components?.queryItems = query

        guard let url = components?.url else {
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Accept"
            )

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return
            }

            let result = try decodeApps(from: data)

            if replacing {
                apps = result.apps
            } else {
                let existing = Set(apps.map(\.id))

                apps.append(
                    contentsOf: result.apps.filter {
                        !existing.contains($0.id)
                    }
                )
            }

            currentPage = page
            hasMorePages = result.hasMore || result.apps.count >= pageSize

            updateCategories()
        } catch {
            print("Dashboard apps error:", error)
        }
    }

    private func updateCategories() {
        categories = Array(
            Set(
                apps
                    .map(\.category)
                    .filter { !$0.isEmpty }
            )
        ).sorted()
    }

    private struct AppsEnvelope: Decodable {
        let apps: [StoreApp]
        let hasMore: Bool

        init(from decoder: Decoder) throws {
            let container = try decoder.container(
                keyedBy: DynamicCodingKeys.self
            )

            var decodedApps: [StoreApp] = []

            for key in ["apps", "data", "items", "results"] {
                guard let codingKey = DynamicCodingKeys(
                    stringValue: key
                ) else {
                    continue
                }

                if let value = try? container.decode(
                    [StoreApp].self,
                    forKey: codingKey
                ) {
                    decodedApps = value
                    break
                }
            }

            apps = decodedApps

            let hasMoreKey = DynamicCodingKeys(
                stringValue: "hasMore"
            )!

            hasMore = (
                try? container.decode(
                    Bool.self,
                    forKey: hasMoreKey
                )
            ) ?? false
        }
    }

    private func decodeApps(
        from data: Data
    ) throws -> (
        apps: [StoreApp],
        hasMore: Bool
    ) {
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(
            [StoreApp].self,
            from: data
        ) {
            return (direct, false)
        }

        let envelope = try decoder.decode(
            AppsEnvelope.self,
            from: data
        )

        return (
            envelope.apps,
            envelope.hasMore
        )
    }
}

private struct DynamicCodingKeys: CodingKey {
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
                        image
                            .resizable()
                            .scaledToFill()

                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(
            width: 50,
            height: 50
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }

    private var placeholder: some View {
        Image(systemName: "app.fill")
            .font(
                .system(size: 24)
            )
            .foregroundStyle(.secondary)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .background(
                Color.secondary.opacity(0.10)
            )
    }
}
