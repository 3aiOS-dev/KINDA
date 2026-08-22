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
        Text("Ø§ÙØ±Ø¦ÙØ³ÙØ©")
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
                        Text("Ø£ÙØ¹Ø§Ø¨ ÙØªØ·Ø¨ÙÙØ§Øª ÙØ§ÙÙØ²ÙØ¯")
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

            Text(searchText.isEmpty ? "ÙØ§ ØªÙØ¬Ø¯ ØªØ·Ø¨ÙÙØ§Øª Ø¨Ø¹Ø¯" : "ÙØ§ ØªÙØ¬Ø¯ ÙØªØ§Ø¦Ø¬")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Text(
                searchText.isEmpty
                    ? "Ø£Ø¶Ù ØªØ·Ø¨ÙÙØ§Ù ÙÙ ÙÙØ­Ø© Ø§ÙØªØ­ÙÙ ÙÙØ¸ÙØ± ÙÙØ§ ÙØ¨Ø§Ø´Ø±Ø©."
                    : "Ø¬Ø±ÙØ¨ Ø§ÙØ¨Ø­Ø« Ø¨Ø§Ø³Ù Ø§ÙØªØ·Ø¨ÙÙ Ø£Ù Bundle ID."
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

                Text(loading ? "\(Int(progress * 100))%" : "ØªØ«Ø¨ÙØª")
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
                        title: "ØªÙØ±Ø§Ø±",
                        isLoading: isDownloading(app)
                    ) {
                        repeatDownload(app)
                    }

                    pillButton(
                        title: "ØªØ«Ø¨ÙØª",
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
            statBox(title: "Ø­Ø¬Ù Ø§ÙØªØ·Ø¨ÙÙ", value: app.sizeValueText)
            statBox(title: "Ø§ÙØ¥ØµØ¯Ø§Ø±", value: app.version)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value.isEmpty ? "â" : value)
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

    var sizeText: String? {
        guard let sizeMB, sizeMB > 0 else { return nil }

        if sizeMB >= 1024 {
            return String(format: "%.2f GB", sizeMB / 1024)
        }

        return String(format: "%.0f MB", sizeMB)
    }

    var sizeValueText: String {
        guard let sizeMB, sizeMB > 0 else { return "â" }
        return String(format: "%.1f", sizeMB)
    }

    var shortIdentifier: String {
        bundleId.split(separator: ".").last.map(String.init) ?? bundleId
    }
}

@MainActor
final class KindaStoreManager: ObservableObject {
    static let shared = KindaStoreManager()

    @Published var apps: [StoreApp] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    // جميع مصادر IPA Store الموجودة في ملف ipastore-sources.md
    private let sourceURLs: [String] = [
        "https://community-apps.sidestore.io/sidecommunity.json",
        "https://qnblackcat.github.io/AltStore/apps.json",
        "https://raw.githubusercontent.com/Neoncat-OG/TrollStore-IPAs/main/apps_esign.json",
        "https://wuxu1.github.io/wuxu-complete-plus.json",
        "https://ipa.cypwn.xyz/cypwn.json",
        "https://aio.yippee.rip/repo.json",
        "https://raw.githubusercontent.com/arichornloveralt/arichornloveralt.github.io/main/apps.json",
        "https://raw.githubusercontent.com/driftywinds/driftywinds.github.io/master/AltStore/apps.json",
        "https://raw.githubusercontent.com/swaggyP36000/TrollStore-IPAs/main/apps_esign.json",
        "https://repo.sourcelocation.dev/apps.json",
        "https://raw.githubusercontent.com/FouadRaheb/AppStore/main/appstore.json",
        "https://julio.hackyouriphone.org/apps.json",
        "https://gbox.run/Public/Source.json",
        "https://apps.nabzclan.vip/repos/altstore.php",
        "https://appstore.nabzclan.vip/repos/altstoreformat2.php",
        "https://appstore.nabzclan.vip/repos/esign.php",
        "https://ittza7aa.com/repo.json",
        "https://apps.altstore.io/",
        "https://appmarket.tech/altstore.json",
        "https://ipa.cypwn.xyz/cypwn_ts.json",
        "https://quarksources.github.io/dist/quantumsource.min.json",
        "https://quarksources.github.io/quarksource-cracked.json",
        "https://wuxu1.github.io/wuxu-complete.json",
        "https://apps.sidestore.io/",
        "https://driftywinds.github.io/repos/esign.json",
        "https://esign.yyyue.xyz/app.json",
        "https://ikghd.site/repo.json",
        "https://quarksources.github.io/quantumsource++.json",
        "https://raw.githubusercontent.com/whoeevee/EeveeSpotify/swift/repo.json",
        "https://xitrix.github.io/iTorrent/AltStore.json",
        "https://ish.app/altstore.json",
        "https://raw.githubusercontent.com/notrifty1/riftysrepo/refs/heads/main/reposource.json",
        "https://altstore.oatmealdome.me/",
        "https://github.com/dvntm0/AltStore/raw/refs/heads/main/feather.json",
        "https://repo.madari.media/nightly/repo.json",
        "https://flyinghead.github.io/flycast-builds/altstore.json",
        "https://pokemmo.eu/altstore/",
        "https://raw.githubusercontent.com/wwg135/wwg135.github.io/main/apps.json",
        "https://opa334.github.io/apps.json",
        "https://poomsmart.github.io/repo/apps.json",
        "https://havoc.app/featured.json",
        "https://repo.chariz.com/featured.json",
        "https://getzbra.com/repo/apps.json",
        "https://level3tjg.me/repo/apps.json",
        "https://mtac.app/repo/apps.json",
        "https://repo.palera.in/apps.json",
        "https://luki120.github.io/apps.json",
        "https://ios.jjolano.me/apps.json",
        "https://ginsu.dev/repo/apps.json",
        "https://miro92.com/repo/apps.json",
        "https://repo.alexia.lol/apps.json",
        "https://creaturecoding.com/repo/apps.json",
        "https://ellekit.space/apps.json",
        "https://sparkdev.me/apps.json",
        "https://tigisoftware.com/repo/apps.json",
        "https://repo.cypwn.xyz/apps.json",
        "https://sourcelocation.github.io/repo/apps.json",
        "https://appstore.nabzclan.vip/repos/gbox.php",
        "https://raw.githubusercontent.com/Nyasami/Ksign/refs/heads/main/repo.json",
        "https://fastsign.dev/repo.json",
        "https://fastsign.dev/repo.lite.json",
        "https://fastsign.dev/repo.lite.altstore.json",
        "https://raw.githubusercontent.com/Gliddd4/gliddd4-repo/refs/heads/main/app.json",
        "https://repo.chungchi365.com/repo.json",
        "https://raw.githubusercontent.com/zigwangles/zigwangles-repo/refs/heads/main/app-repo.json",
        "https://raw.githubusercontent.com/AntonP29/AntonP29-Repo/refs/heads/main/repo.json",
        "https://balackburn.github.io/Apollo/apps.json",
        "https://raw.githubusercontent.com/Auties00/Artemis/refs/heads/main/source.json",
        "https://bunduuk.github.io/altstore-source/apps.json",
        "https://therealfoxster.github.io/altsource/apps.json",
        "https://github.com/khcrysalis/Feather/raw/main/app-repo.json",
        "https://alts.lao.sb",
        "https://buildbot.libretro.com/stable/altstore.json",
        "https://raw.githubusercontent.com/LiveContainer/LiveContainer/refs/heads/main/apps.json",
        "https://theodyssey.dev/altstore/odysseysource.json",
        "https://raw.githubusercontent.com/vizunchik/AltStoreRus/master/apps.json",
        "https://alt.crystall1ne.dev",
        "https://provenance-emu.com/apps.json",
        "https://randomblock1.com/altstore/apps.json",
        "https://spotc-repo.yodaluca.dev/AltStore%20Repo.json",
        "https://taurine.app/altstore/taurinestore.json",
        "https://alt.getutm.app",
        "https://raw.githubusercontent.com/Balackburn/YTLitePlusAltstore/main/apps.json",
        "https://azu0609.github.io/repo/altstore_repo.json",
        "https://raw.githubusercontent.com/cbruegg/altstore-source/refs/heads/main/source.json",
        "https://alt.thatstel.la/",
        "https://connect.sidestore.io/apps.json",
        "https://cranci.tech/repo.json",
        "https://binnichtaktiv.signapp.me/repo/esign.json",
        "https://hann8n.github.io/JackCracks/MovieboxPro.json",
        "https://ia601404.us.archive.org/11/items/ms_20220903/MS.json",
        "https://ia601505.us.archive.org/10/items/motoca-store/Motoca%20Store.json",
        "https://ipa.thuthuatjb.com/repo",
        "https://raw.githubusercontent.com/lo-cafe/winston-altstore/main/apps.json",
        "https://quarksources.github.io/quantumsource.json",
        "https://raw.githubusercontent.com/Omni-Development/The-Omni-Repository/refs/heads/main/app-repo.json",
        "https://raw.githubusercontent.com/RealBlackAstronaut/CelestialRepo/main/CelestialRepo.json",
        "https://raw.githubusercontent.com/WhySooooFurious/Ultimate-Sideloading-Guide/refs/heads/main/app-repo.json",
        "https://raw.githubusercontent.com/arichornloverALT/arichornloveralt.github.io/main/apps.json",
        "https://raw.githubusercontent.com/arichornloverALT/arichornloveralt.github.io/main/apps2.json",
        "https://raw.githubusercontent.com/actuallyaridan/NeoFreeBird/refs/heads/main/AltSource.json",
        "https://raw.githubusercontent.com/ssalggnikool/.github/refs/heads/main/b.json",
        "https://raw.githubusercontent.com/sinceohsix/lcdl-repo/refs/heads/main/repo.json",
        "https://repo.zsign.app/repo.json",
        "https://repos.yattee.stream/alt/apps.json",
        "https://rickowens.su/repo.json",
        "https://tweakrain.pages.dev/ios/altstore.json",
        "https://website.burrito.software/altstore/channels/burritosource.json",
        "https://www.sachcharak.com/esign/repo/RAK.json",
        "https://raw.githubusercontent.com/DatOneFlareon/The-SEU-app-repo-for-the-gangalang/refs/heads/main/SEU.json",
        "https://delvek.net/repo.json",
        "https://raw.githubusercontent.com/qnblackcat/AltStore/gh-pages/apps.json",
        "https://hottubapp.io/altstore",
        "https://altstore.ignitedemulator.com",
    ]

    func filtered(_ searchText: String) -> [StoreApp] {
        guard !searchText.isEmpty else { return apps }

        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.bundleId.localizedCaseInsensitiveContains(searchText)
            || $0.appDescription.localizedCaseInsensitiveContains(searchText)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        let sources = sourceURLs

        // تحميل كل المصادر بالتوازي.
        // فشل مصدر واحد لا يمنع ظهور تطبيقات المصادر الأخرى.
        let loadedApps = await withTaskGroup(of: [StoreApp].self, returning: [[StoreApp]].self) { group in
            for source in sources {
                group.addTask {
                    await Self.loadSource(source)
                }
            }

            var result: [[StoreApp]] = []
            for await sourceApps in group {
                if !sourceApps.isEmpty {
                    result.append(sourceApps)
                }
            }
            return result
        }

        var uniqueApps: [StoreApp] = []
        var seenKeys = Set<String>()

        for sourceApps in loadedApps {
            for app in sourceApps {
                let bundleKey = app.bundleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let ipaKey = app.ipaURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let nameKey = app.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                let key: String
                if !bundleKey.isEmpty {
                    key = "bundle:\(bundleKey)"
                } else if !ipaKey.isEmpty {
                    key = "ipa:\(ipaKey)"
                } else {
                    key = "name:\(nameKey)"
                }

                if seenKeys.insert(key).inserted {
                    uniqueApps.append(app)
                }
            }
        }

        apps = uniqueApps
        isLoading = false

        if apps.isEmpty {
            errorMessage = "لم يتم العثور على تطبيقات من المصادر الحالية."
        }
    }

    private static func loadSource(_ source: String) async -> [StoreApp] {
        guard let url = URL(string: source) else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                !data.isEmpty
            else {
                return []
            }

            return parseApps(data: data, sourceURL: source)
        } catch {
            return []
        }
    }

    private static func parseApps(data: Data, sourceURL: String) -> [StoreApp] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else {
            return []
        }

        var records: [[String: Any]] = []

        func collect(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                // AltStore / SideStore تستخدم غالباً apps.
                if let apps = dictionary["apps"] {
                    collect(apps)
                }

                // بعض المصادر تستخدم data/results/items.
                if let data = dictionary["data"] {
                    collect(data)
                }
                if let results = dictionary["results"] {
                    collect(results)
                }
                if let items = dictionary["items"] {
                    collect(items)
                }

                // إذا كان هذا السجل يحتوي رابط IPA أو الاسم، اعتبره تطبيقاً.
                let hasName =
                    dictionary["name"] != nil ||
                    dictionary["title"] != nil

                let hasIPA =
                    dictionary["downloadURL"] != nil ||
                    dictionary["download_url"] != nil ||
                    dictionary["ipa"] != nil ||
                    dictionary["ipa_url"] != nil ||
                    dictionary["url"] != nil

                if hasName && hasIPA {
                    records.append(dictionary)
                }

                // دعم القواميس المتداخلة.
                for (key, child) in dictionary {
                    let lowerKey = key.lowercased()
                    if lowerKey == "apps" ||
                        lowerKey == "data" ||
                        lowerKey == "results" ||
                        lowerKey == "items" ||
                        lowerKey == "applications" {
                        collect(child)
                    }
                }
            } else if let array = value as? [Any] {
                for item in array {
                    collect(item)
                }
            }
        }

        collect(object)

        var result: [StoreApp] = []
        var seen = Set<String>()

        for record in records {
            guard let app = makeStoreApp(from: record, sourceURL: sourceURL) else {
                continue
            }

            let key = app.bundleId.isEmpty
                ? (app.ipaURL.lowercased())
                : (app.bundleId.lowercased())

            if !key.isEmpty && seen.insert(key).inserted {
                result.append(app)
            }
        }

        return result
    }

    private static func makeStoreApp(
        from dictionary: [String: Any],
        sourceURL: String
    ) -> StoreApp? {
        func string(_ keys: [String]) -> String {
            for key in keys {
                if let value = dictionary[key] as? String,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                if let value = dictionary[key] as? NSNumber {
                    return value.stringValue
                }
            }
            return ""
        }

        func number(_ keys: [String]) -> Double? {
            for key in keys {
                if let value = dictionary[key] as? NSNumber {
                    return value.doubleValue
                }
                if let value = dictionary[key] as? String,
                   let number = Double(value.replacingOccurrences(of: ",", with: ".")) {
                    return number
                }
            }
            return nil
        }

        let name = string(["name", "title", "appName", "app_name"])
        let version = string(["version", "versionName", "version_name"])
        let bundleId = string([
            "bundleIdentifier",
            "bundle_identifier",
            "bundleID",
            "bundle_id",
            "identifier",
            "id"
        ])

        let description = string([
            "description",
            "subtitle",
            "summary",
            "desc"
        ])

        let category = string([
            "category",
            "genre",
            "section"
        ])

        let icon = string([
            "iconURL",
            "icon_url",
            "icon",
            "iconURLTemplate",
            "icon_url_template"
        ])

        var ipaURL = string([
            "downloadURL",
            "download_url",
            "ipaURL",
            "ipa_url",
            "ipa",
            "download",
            "url"
        ])

        // بعض المصادر تضع رابط التحميل داخل versions.
        if ipaURL.isEmpty, let versions = dictionary["versions"] as? [[String: Any]] {
            for versionRecord in versions {
                ipaURL = stringFromDictionary(
                    versionRecord,
                    keys: ["downloadURL", "download_url", "ipaURL", "ipa_url", "ipa", "url"]
                )
                if !ipaURL.isEmpty {
                    break
                }
            }
        }

        guard !name.isEmpty, !ipaURL.isEmpty else {
            return nil
        }

        let finalIcon = icon
        let finalID = !bundleId.isEmpty
            ? bundleId
            : stableID(name: name, ipaURL: ipaURL)

        return StoreApp(
            id: finalID,
            name: name,
            version: version,
            bundleId: bundleId,
            appDescription: description,
            category: category,
            iconURL: finalIcon,
            ipaURL: ipaURL,
            sizeMB: number([
                "sizeMB",
                "size_mb",
                "size",
                "fileSizeMB",
                "file_size_mb"
            ])
        )
    }

    private static func stringFromDictionary(
        _ dictionary: [String: Any],
        keys: [String]
    ) -> String {
        for key in keys {
            if let value = dictionary[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private static func stableID(name: String, ipaURL: String) -> String {
        let raw = "\(name)|\(ipaURL)"
        var hash: UInt64 = 1469598103934665603

        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }

        return String(format: "%016llx", hash)
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
