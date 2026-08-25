import SwiftUI
import CoreData
import NimbleViews
import AudioToolbox
import UserNotifications
import UIKit

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

    // المصدر الوحيد هو لوحة التحكم.
    @State private var selectedSource = "لوحة التحكم"
    @State private var selectedCategory = "الكل"
    @State private var displayLimit = 50
    @State private var isLoadingNextPage = false

    @State private var activeDownloads: [String: String] = [:]
    @State private var downloadWatchTasks: [String: Task<Void, Never>] = [:]
    @State private var downloadProgress: [String: Double] = [:]
    @State private var backgroundTaskTokens: [String: BackgroundExecutionToken] = [:]

    @FetchRequest(
        entity: Imported.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Imported.date, ascending: false)
        ],
        animation: .snappy
    )
    private var importedApps: FetchedResults<Imported>

    private var filteredApps: [StoreApp] {
        storeManager.filtered(
            searchText,
            source: selectedSource,
            category: selectedCategory
        )
    }

    private var visibleApps: [StoreApp] {
        Array(filteredApps.prefix(displayLimit))
    }

    private var hasMoreVisibleApps: Bool {
        if filteredApps.count > visibleApps.count {
            return true
        }

        return storeManager.hasMoreServerPages
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
                                    ForEach(
                                        Array(visibleApps.enumerated()),
                                        id: \.element.id
                                    ) { index, app in
                                        if selectedAppID == app.id {
                                            expandedItem(app)
                                        } else {
                                            rowView(app)
                                        }

                                        if index == visibleApps.count - 1 {
                                            Color.clear
                                                .frame(height: 1)
                                                .onAppear {
                                                    Task {
                                                        await loadMoreIfNeeded()
                                                    }
                                                }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 6)

                                if hasMoreVisibleApps {
                                    nextPageButton
                                        .padding(.top, 14)
                                        .padding(.horizontal, 16)
                                }
                            }
                        } header: {
                            VStack(spacing: 0) {
                                titleHeader

                                searchBar
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)

                                sourceAndCategoryFilters
                                    .padding(.bottom, 6)
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
                    displayLimit = 50
                    selectedAppID = nil
                    await storeManager.load()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            await StoreNotificationManager.requestPermission()

            if storeManager.apps.isEmpty {
                await storeManager.load()
            }
        }
        .onDisappear {
            // DownloadManager يستمر بعملية التنزيل عند الانتقال بين التبويبات.
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
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var sourceAndCategoryFilters: some View {
        VStack(spacing: 7) {
            // لا توجد مصادر خارجية هنا. هذا الزر يعرض فقط تطبيقات لوحة التحكم.
            HStack(spacing: 7) {
                filterChip(
                    title: "لوحة التحكم",
                    selected: selectedSource == "لوحة التحكم"
                ) {
                    selectedSource = "لوحة التحكم"
                    selectedCategory = "الكل"
                    displayLimit = 50
                    selectedAppID = nil
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 16)

            if storeManager.availableCategories.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(
                            storeManager.availableCategories,
                            id: \.self
                        ) { category in
                            filterChip(
                                title: category,
                                selected: selectedCategory == category
                            ) {
                                selectedCategory = category
                                displayLimit = 50
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private func filterChip(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? .primary : .secondary)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(
                    selected
                        ? Color.primary.opacity(0.12)
                        : Color.secondary.opacity(0.07),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            Color.primary.opacity(selected ? 0.10 : 0.05),
                            lineWidth: 0.6
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private var nextPageButton: some View {
        Button {
            Task {
                await loadMoreIfNeeded(force: true)
            }
        } label: {
            HStack(spacing: 8) {
                if isLoadingNextPage || storeManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(
                    isLoadingNextPage
                        ? "جاري تحميل التالي..."
                        : "التالي"
                )
                .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoadingNextPage || storeManager.isLoading)
    }

    private func loadMoreIfNeeded(force: Bool = false) async {
        guard !isLoadingNextPage else { return }

        // أولاً نعرض التطبيقات الموجودة في الذاكرة.
        if displayLimit < filteredApps.count {
            displayLimit += 50
            return
        }

        guard storeManager.hasMoreServerPages else {
            return
        }

        guard force || displayLimit >= filteredApps.count else {
            return
        }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        await storeManager.loadNextServerPage()

        if displayLimit < filteredApps.count {
            displayLimit += 50
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)

            Text(
                searchText.isEmpty
                    ? "لا توجد تطبيقات بعد"
                    : "لا توجد نتائج"
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primary)

            Text(
                searchText.isEmpty
                    ? "أضف تطبيقاً من لوحة التحكم ليظهر هنا مباشرة."
                    : "جرّب البحث باسم التطبيق أو Bundle ID."
            )
            .font(
                .system(
                    size: 11,
                    weight: .regular,
                    design: .monospaced
                )
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
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
                withAnimation(
                    .spring(response: 0.32, dampingFraction: 0.86)
                ) {
                    selectedAppID = app.id
                }
            } label: {
                HStack(spacing: 12) {
                    StoreIconView(
                        urlString: app.iconURL,
                        size: 44
                    )

                    Text(app.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .trailing
                        )
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
                            .stroke(
                                Color.secondary.opacity(0.25),
                                lineWidth: 2
                            )
                            .frame(width: 14, height: 14)

                        Circle()
                            .trim(
                                from: 0,
                                to: max(0.03, progress)
                            )
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(
                                    lineWidth: 2,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 14, height: 14)
                            .rotationEffect(.degrees(-90))
                            .animation(
                                .linear(duration: 0.2),
                                value: progress
                            )
                    }
                }

                Text(
                    loading
                        ? "\(Int(progress * 100))%"
                        : "تثبيت"
                )
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .monospacedDigit()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Color.secondary.opacity(0.14),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        Color.primary.opacity(0.08),
                        lineWidth: 0.6
                    )
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
                    withAnimation(
                        .spring(response: 0.32, dampingFraction: 0.86)
                    ) {
                        selectedAppID = nil
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(
                            .regularMaterial,
                            in: Circle()
                        )
                        .shadow(
                            color: .black.opacity(0.18),
                            radius: 10,
                            y: 4
                        )
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
                AsyncImage(
                    url: URL(string: app.iconURL)
                ) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.black)
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .blur(radius: 58)
                .overlay(Color.black.opacity(0.46))
                .clipped()
            }

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.20)

            VStack(spacing: 16) {
                StoreIconView(
                    urlString: app.iconURL,
                    size: 108
                )
                .shadow(
                    color: .black.opacity(0.35),
                    radius: 16,
                    y: 10
                )

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
        .clipShape(
            RoundedRectangle(
                cornerRadius: 32,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 32,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.10),
                lineWidth: 0.8
            )
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
            .background(
                Color.white.opacity(0.22),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func statsRow(_ app: StoreApp) -> some View {
        HStack(spacing: 8) {
            statBox(
                title: "حجم التطبيق",
                value: app.sizeValueText
            )

            statBox(
                title: "الإصدار",
                value: app.version
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .center
        )
    }

    private func statBox(
        title: String,
        value: String
    ) -> some View {
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
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.06),
                lineWidth: 0.6
            )
        }
    }

    private func isDownloading(_ app: StoreApp) -> Bool {
        activeDownloads[app.id] != nil
    }

    private func install(_ app: StoreApp) {
        playInstallSound()

        StoreNotificationManager.postStarted(
            appName: app.name,
            version: app.version
        )

        Task {
            await startStoreDownload(for: app)
        }
    }

    private func resolveDownloadURL(
        _ rawURL: String
    ) async -> URL? {
        guard let url = URL(string: rawURL) else {
            return nil
        }

        let scheme = url.scheme?.lowercased() ?? ""

        if scheme == "http" || scheme == "https" {
            return url
        }

        guard scheme == "itms-services" else {
            return nil
        }

        guard
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ),
            let manifestString = components.queryItems?.first(
                where: {
                    $0.name.caseInsensitiveCompare("url")
                        == .orderedSame
                }
            )?.value,
            let manifestURL = URL(string: manifestString)
        else {
            return nil
        }

        do {
            var request = URLRequest(url: manifestURL)
            request.timeoutInterval = 20
            request.cachePolicy =
                .reloadIgnoringLocalCacheData
            request.setValue(
                "application/xml, text/xml, */*",
                forHTTPHeaderField: "Accept"
            )

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode),
                !data.isEmpty,
                let xml = String(
                    data: data,
                    encoding: .utf8
                )
            else {
                return nil
            }

            let pattern =
                #"<key>\s*url\s*</key>\s*<string>\s*([^<\s]+)\s*</string>"#

            guard
                let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                )
            else {
                return nil
            }

            let range = NSRange(
                xml.startIndex..<xml.endIndex,
                in: xml
            )

            guard
                let match = regex.firstMatch(
                    in: xml,
                    options: [],
                    range: range
                ),
                match.numberOfRanges > 1,
                let valueRange = Range(
                    match.range(at: 1),
                    in: xml
                )
            else {
                return nil
            }

            let ipaString = String(xml[valueRange])
                .replacingOccurrences(
                    of: "&amp;",
                    with: "&"
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard
                let ipaURL = URL(string: ipaString),
                let ipaScheme =
                    ipaURL.scheme?.lowercased(),
                ipaScheme == "http" ||
                ipaScheme == "https"
            else {
                return nil
            }

            return ipaURL
        } catch {
            return nil
        }
    }

    private func playInstallSound() {
        AudioServicesPlaySystemSound(1104)
    }

    private func repeatDownload(_ app: StoreApp) {
        Task {
            await startStoreDownload(for: app)
        }
    }

    private func startStoreDownload(
        for app: StoreApp
    ) async {
        guard !isDownloading(app) else {
            return
        }

        guard
            let url = await resolveDownloadURL(
                app.ipaURL.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
        else {
            UIAlertController.showAlertWithOk(
                title: .localized("خطأ"),
                message: .localized(
                    "رابط ملف IPA غير صالح أو لا يحتوي على ملف IPA مباشر."
                )
            )
            return
        }

        let existingImportedUUIDs = Set(
            importedApps.compactMap { $0.uuid }
        )

        let startedAt = Date()

        let downloadID =
            "KindaStore_\(app.id)_\(UUID().uuidString)"

        let backgroundToken =
            BackgroundExecutionToken(
                name: "KindaStore IPA Download"
            )

        backgroundTaskTokens[app.id] =
            backgroundToken

        let download = downloadManager.startDownload(
            from: url,
            id: downloadID
        )

        activeDownloads[app.id] = download.id

        watchStoreDownload(
            download,
            app: app,
            existingImportedUUIDs:
                existingImportedUUIDs,
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
            let timeout: UInt64 =
                15 * 60 * 1_000_000_000

            let pollInterval: UInt64 =
                300_000_000

            let deadline =
                DispatchTime.now().uptimeNanoseconds
                + timeout

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

                if let currentDownload =
                    DownloadManager.shared.getDownload(
                        by: downloadID
                    ) {
                    downloadProgress[app.id] =
                        currentDownload.progress

                    if currentDownload.totalBytes > 0 {
                        StoreNotificationManager.postProgress(
                            appName: app.name,
                            progress: currentDownload.progress
                        )
                    }

                    if currentDownload.totalBytes > 0,
                       currentDownload.progress >= 0.999 {
                        reachedDownloadCompletion = true
                    }
                } else if reachedDownloadCompletion {
                    downloadProgress[app.id] = 1.0
                }

                if DispatchTime.now().uptimeNanoseconds
                    >= deadline {
                    break
                }

                try? await Task.sleep(
                    nanoseconds: pollInterval
                )
            }

            guard !Task.isCancelled else {
                return
            }

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
               identifier.caseInsensitiveCompare(
                    app.bundleId
               ) == .orderedSame {
                return true
            }

            if let name = imported.name,
               let version = imported.version,
               !app.version.isEmpty,
               name.localizedCaseInsensitiveCompare(
                    app.name
               ) == .orderedSame,
               version.caseInsensitiveCompare(
                    app.version
               ) == .orderedSame {
                return true
            }

            if let name = imported.name {
                return name.localizedCaseInsensitiveCompare(
                    app.name
                ) == .orderedSame
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

        backgroundTaskTokens
            .removeValue(forKey: app.id)?
            .end()

        StoreNotificationManager.postFinished(
            appName: app.name,
            success: success
        )

        guard success, imported != nil else {
            UIAlertController.showAlertWithOk(
                title: .localized("خطأ"),
                message: .localized(
                    "تعذر تنزيل أو استيراد التطبيق. تأكد من أن رابط IPA يعمل بشكل صحيح."
                )
            )
            return
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(
                    "ksign.openLibraryTab"
                ),
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
    let sourceName: String
    let isServerApp: Bool

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
        case sourceName
        case isServerApp
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
        sizeMB: Double?,
        sourceName: String,
        isServerApp: Bool
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
        self.sourceName = sourceName
        self.isServerApp = isServerApp
    }

    init(from decoder: Decoder) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        id =
            (try? container.decode(
                String.self,
                forKey: .id
            )) ?? UUID().uuidString

        name =
            (try? container.decode(
                String.self,
                forKey: .name
            )) ?? ""

        version =
            (try? container.decode(
                String.self,
                forKey: .version
            )) ?? ""

        bundleId =
            (try? container.decode(
                String.self,
                forKey: .bundleId
            )) ?? ""

        appDescription =
            (try? container.decode(
                String.self,
                forKey: .appDescription
            )) ?? ""

        category =
            (try? container.decode(
                String.self,
                forKey: .category
            )) ?? "أخرى"

        iconURL =
            (try? container.decode(
                String.self,
                forKey: .iconURL
            )) ?? ""

        ipaURL =
            (try? container.decode(
                String.self,
                forKey: .ipaURL
            )) ?? ""

        sizeMB =
            try? container.decode(
                Double.self,
                forKey: .sizeMB
            )

        sourceName =
            (try? container.decode(
                String.self,
                forKey: .sourceName
            )) ?? "لوحة التحكم"

        isServerApp =
            (try? container.decode(
                Bool.self,
                forKey: .isServerApp
            )) ?? true
    }

    var sizeText: String? {
        guard let sizeMB, sizeMB > 0 else {
            return nil
        }

        if sizeMB >= 1024 {
            return String(
                format: "%.2f GB",
                sizeMB / 1024
            )
        }

        return String(
            format: "%.0f MB",
            sizeMB
        )
    }

    var sizeValueText: String {
        guard let sizeMB, sizeMB > 0 else {
            return "—"
        }

        return String(
            format: "%.1f",
            sizeMB
        )
    }

    var shortIdentifier: String {
        bundleId
            .split(separator: ".")
            .last
            .map(String.init)
            ?? bundleId
    }
}

@MainActor
final class KindaStoreManager: ObservableObject {
    static let shared = KindaStoreManager()

    // ============================================================
    // المصدر الوحيد: لوحة التحكم / Supabase
    // ============================================================
    private let baseURL =
        "https://ibskoyypugseeixzntyt.supabase.co"

    private let apiKey =
        "sb_publishable_McRq3FTx_r7pL2PbGk8YBA_mMnJmtFm"

    private let pageSize = 50
    private var serverPage = 0
    private(set) var hasMoreServerPages = true

    @Published var apps: [StoreApp] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // لا توجد أي مصادر خارجية.
    @Published private(set) var availableSources: [String] = [
        "لوحة التحكم"
    ]

    @Published private(set) var availableCategories: [String] = [
        "الكل"
    ]

    private init() {}

    func filtered(
        _ searchText: String,
        source: String = "لوحة التحكم",
        category: String = "الكل"
    ) -> [StoreApp] {
        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return apps.filter { app in
            // جميع البيانات هنا من لوحة التحكم فقط.
            let sourceMatch =
                app.sourceName.caseInsensitiveCompare(
                    "لوحة التحكم"
                ) == .orderedSame ||
                app.isServerApp

            let requestedSourceMatch =
                source == "الكل" ||
                source == "لوحة التحكم"

            let categoryMatch =
                category == "الكل" ||
                app.category.caseInsensitiveCompare(
                    category
                ) == .orderedSame

            let searchMatch =
                query.isEmpty ||
                app.name.localizedCaseInsensitiveContains(
                    query
                ) ||
                app.bundleId.localizedCaseInsensitiveContains(
                    query
                ) ||
                app.appDescription.localizedCaseInsensitiveContains(
                    query
                )

            return sourceMatch &&
                requestedSourceMatch &&
                categoryMatch &&
                searchMatch
        }
    }

    func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        serverPage = 0
        hasMoreServerPages = true
        apps.removeAll(keepingCapacity: true)

        // تحميل لوحة التحكم فقط.
        let serverResult =
            await loadServerPage(page: 0)

        merge(serverResult)

        serverPage = 1
        hasMoreServerPages =
            serverResult.count == pageSize

        rebuildFilters()

        isLoading = false

        if apps.isEmpty {
            errorMessage =
                "لم يتم العثور على تطبيقات من لوحة التحكم."
        }
    }

    func loadNextServerPage() async {
        guard hasMoreServerPages,
              !isLoading
        else {
            return
        }

        isLoading = true

        let page = serverPage
        let newApps =
            await loadServerPage(page: page)

        if newApps.isEmpty {
            hasMoreServerPages = false
        } else {
            merge(newApps)

            serverPage += 1

            hasMoreServerPages =
                newApps.count == pageSize

            rebuildFilters()
        }

        isLoading = false
    }

    private func loadServerPage(
        page: Int
    ) async -> [StoreApp] {
        let offset = page * pageSize

        guard
            let url = URL(
                string:
                    "\(baseURL)/rest/v1/store_apps"
            )
        else {
            return []
        }

        var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(
                name: "select",
                value: "*"
            ),
            URLQueryItem(
                name: "order",
                value: "created_at.desc"
            ),
            URLQueryItem(
                name: "offset",
                value: String(offset)
            ),
            URLQueryItem(
                name: "limit",
                value: String(pageSize)
            )
        ]

        guard
            let requestURL = components?.url
        else {
            return []
        }

        var request =
            URLRequest(url: requestURL)

        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy =
            .reloadIgnoringLocalCacheData

        request.setValue(
            apiKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        do {
            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard
                let http =
                    response as? HTTPURLResponse,
                (200...299).contains(
                    http.statusCode
                ),
                !data.isEmpty
            else {
                return []
            }

            return try JSONDecoder().decode(
                [StoreApp].self,
                from: data
            )
        } catch {
            return []
        }
    }

    private func merge(
        _ newApps: [StoreApp]
    ) {
        guard !newApps.isEmpty else {
            return
        }

        var existing = Set(
            apps.map(Self.uniqueKey)
        )

        for app in newApps {
            let key =
                Self.uniqueKey(for: app)

            if existing.insert(key).inserted {
                apps.append(app)
            }
        }
    }

    private func rebuildFilters() {
        let categories = Set(
            apps
                .map {
                    $0.category.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }
        )

        availableCategories =
            ["الكل"] + categories.sorted()

        // المصدر الوحيد.
        availableSources =
            ["لوحة التحكم"]
    }

    private static func uniqueKey(
        for app: StoreApp
    ) -> String {
        let bundle =
            app.bundleId
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        if !bundle.isEmpty {
            return "bundle:\(bundle)"
        }

        return
            "ipa:\(app.ipaURL.lowercased())"
    }
}

final class BackgroundExecutionToken {
    let id: UIBackgroundTaskIdentifier

    init(name: String) {
        id =
            UIApplication.shared.beginBackgroundTask(
                withName: name
            ) { }
    }

    func end() {
        guard id != .invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(id)
    }

    deinit {
        end()
    }
}

enum StoreNotificationManager {
    private static let center =
        UNUserNotificationCenter.current()

    static func requestPermission() async {
        _ = try? await center.requestAuthorization(
            options: [
                .alert,
                .sound,
                .badge
            ]
        )
    }

    static func postStarted(
        appName: String,
        version: String
    ) {
        post(
            identifier:
                "KindaStore.install.started.\(safeID(appName))",
            title: "Xcode",
            body:
                "بدأ تنزيل \(appName) \(version.isEmpty ? "" : "— \(version)")"
        )
    }

    static func postProgress(
        appName: String,
        progress: Double
    ) {
        let percent =
            min(
                100,
                max(
                    0,
                    Int(progress * 100)
                )
            )

        guard percent > 0,
              percent % 10 == 0
        else {
            return
        }

        post(
            identifier:
                "KindaStore.install.progress.\(safeID(appName))",
            title: "Xcode",
            body:
                "تنزيل \(appName): \(percent)%"
        )
    }

    static func postFinished(
        appName: String,
        success: Bool
    ) {
        post(
            identifier:
                "KindaStore.install.finished.\(safeID(appName))",
            title: "Xcode",
            body:
                success
                    ? "اكتمل تنزيل \(appName) وسيتم فتح المكتبة."
                    : "فشل تنزيل \(appName)."
        )
    }

    private static func post(
        identifier: String,
        title: String,
        body: String
    ) {
        let content =
            UNMutableNotificationContent()

        content.title = title
        content.body = body
        content.sound = .default

        let request =
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )

        center.add(request)
    }

    private static func safeID(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: " ",
                with: "_"
            )
            .replacingOccurrences(
                of: "/",
                with: "_"
            )
    }
}

struct StoreIconView: View {
    let urlString: String
    let size: CGFloat

    var body: some View {
        AsyncImage(
            url: URL(string: urlString)
        ) { phase in
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
        .frame(
            width: size,
            height: size
        )
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
        .fill(
            Color.secondary.opacity(0.15)
        )
        .overlay {
            Image(systemName: "app.dashed")
                .font(
                    .system(
                        size: size / 3,
                        weight: .light
                    )
                )
                .foregroundStyle(.secondary)
        }
    }
}
