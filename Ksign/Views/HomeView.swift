//
// HomeView.swift
// KINDA
//
// الرئيسية:
// • التطبيقات من لوحة التحكم فقط.
// • لا توجد صفحة تفاصيل.
// • زر "تثبيت" يبدأ تنزيل IPA مباشرة.
// • بعد اكتمال الاستيراد تظهر InstallPreview مباشرة.
// • استيراد IPA من الملفات أو الرابط موجود هنا.
// • لا يوجد تبويب توقيع.
//

import SwiftUI
import CoreData
import NimbleViews
import UniformTypeIdentifiers
import UIKit

enum KindaTheme {
    static var pageBG: Color { Color(.systemBackground) }
    static var cardBG: Color { Color(.secondarySystemGroupedBackground) }
}

struct KindaGridBackground: View {
    private let spacing: CGFloat = 48

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
                with: .color(.primary.opacity(0.045)),
                lineWidth: 0.7
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

@MainActor
struct HomeView: View {
    @StateObject private var storeManager = KindaStoreManager.shared
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var searchText = ""
    @State private var selectedCategory = "الكل"

    @State private var showFileImporter = false
    @State private var showURLSheet = false
    @State private var ipaURL = ""

    @State private var activeDownloadID: String?
    @State private var downloadProgress: [String: Double] = [:]

    @State private var selectedInstallUUID: String?

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

    private var filteredApps: [StoreApp] {
        storeManager.apps.filter { app in
            let matchesSearch =
                searchText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ||
                app.name.localizedCaseInsensitiveContains(
                    searchText
                ) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(
                    searchText
                )

            let matchesCategory =
                selectedCategory == "الكل" ||
                app.category == selectedCategory

            return matchesSearch && matchesCategory
        }
    }

    private var selectedImportedApp: Imported? {
        guard let uuid = selectedInstallUUID else {
            return nil
        }

        return importedApps.first {
            $0.uuid == uuid
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindaTheme.pageBG
                    .ignoresSafeArea()

                KindaGridBackground()

                ScrollView(
                    showsIndicators: false
                ) {
                    LazyVStack(
                        spacing: 11
                    ) {
                        titleHeader
                        searchBar
                        importButtons
                        categoryBar

                        if filteredApps.isEmpty {
                            emptyState
                        } else {
                            ForEach(
                                filteredApps
                            ) { app in
                                appRow(app)
                            }
                        }

                        if storeManager.hasMorePages {
                            nextButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 35)
                }
                .refreshable {
                    await storeManager.reload()
                }
            }
            .toolbar(
                .hidden,
                for: .navigationBar
            )
        }
        .environment(
            \.layoutDirection,
            .rightToLeft
        )
        .task {
            if storeManager.apps.isEmpty {
                await storeManager.reload()
            }
        }
        .sheet(
            isPresented:
                Binding(
                    get: {
                        selectedInstallUUID != nil &&
                        selectedImportedApp != nil
                    },
                    set: { value in
                        if !value {
                            selectedInstallUUID = nil
                        }
                    }
                )
        ) {
            if let app = selectedImportedApp {
                InstallPreviewView(
                    app: app
                )
                .presentationDetents(
                    [.height(220), .medium]
                )
                .presentationDragIndicator(
                    .visible
                )
            }
        }
        .sheet(
            isPresented:
                $showURLSheet
        ) {
            urlImportSheet
        }
        .fileImporter(
            isPresented:
                $showFileImporter,
            allowedContentTypes: [
                .ipa,
                .tipa
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for:
                    NSNotification.Name(
                        "kinda.directInstall"
                    )
            )
        ) { notification in
            guard
                let uuid =
                    notification.userInfo?[
                        "uuid"
                    ] as? String
            else {
                return
            }

            selectedInstallUUID = uuid
        }
    }

    // MARK: Header

    private var titleHeader: some View {
        VStack(spacing: 4) {
            Text("الرئيسية")
                .font(
                    .system(
                        size: 20,
                        weight: .bold
                    )
                )

            Text("تطبيقات لوحة التحكم")
                .font(
                    .system(
                        size: 10,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.top, 17)
        .padding(.bottom, 4)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(
                systemName:
                    "magnifyingglass"
            )
            .foregroundStyle(
                .secondary
            )

            TextField(
                "ألعاب وتطبيقات والمزيد",
                text:
                    $searchText
            )
            .textFieldStyle(
                .plain
            )
            .multilineTextAlignment(
                .trailing
            )
            .textInputAutocapitalization(
                .never
            )
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(
                    .plain
                )
            }
        }
        .padding(
            .horizontal,
            12
        )
        .frame(height: 42)
        .background(
            .ultraThinMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
        )
    }

    private var importButtons: some View {
        HStack(spacing: 9) {
            importButton(
                title:
                    "استيراد من الملفات",
                icon:
                    "folder.fill"
            ) {
                showFileImporter = true
            }

            importButton(
                title:
                    "استيراد من الرابط",
                icon:
                    "link"
            ) {
                ipaURL = ""
                showURLSheet = true
            }
        }
    }

    private func importButton(
        title: String,
        icon: String,
        action:
            @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            HStack(spacing: 8) {
                Image(
                    systemName: icon
                )
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )

                Text(title)
                    .font(
                        .system(
                            size: 11,
                            weight: .semibold
                        )
                    )
                    .lineLimit(1)
            }
            .foregroundStyle(
                .primary
            )
            .frame(
                maxWidth: .infinity
            )
            .frame(height: 42)
            .background(
                .ultraThinMaterial,
                in:
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
            )
        }
        .buttonStyle(
            .plain
        )
    }

    private var categoryBar: some View {
        Group {
            if storeManager.categories.count > 1 {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(spacing: 7) {
                        categoryChip(
                            title: "الكل",
                            selected:
                                selectedCategory == "الكل"
                        ) {
                            selectedCategory =
                                "الكل"
                        }

                        ForEach(
                            storeManager.categories,
                            id: \.self
                        ) { category in
                            categoryChip(
                                title:
                                    category,
                                selected:
                                    selectedCategory ==
                                    category
                            ) {
                                selectedCategory =
                                    category
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryChip(
        title: String,
        selected: Bool,
        action:
            @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            Text(title)
                .font(
                    .system(
                        size: 11,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    selected
                        ? .primary
                        : .secondary
                )
                .padding(
                    .horizontal,
                    12
                )
                .frame(height: 29)
                .background(
                    selected
                        ? Color.primary.opacity(
                            0.12
                        )
                        : Color.secondary.opacity(
                            0.07
                        ),
                    in: Capsule()
                )
        }
        .buttonStyle(
            .plain
        )
    }

    // MARK: App row

    private func appRow(
        _ app: StoreApp
    ) -> some View {
        HStack(spacing: 11) {
            DashboardIconView(
                urlString:
                    app.iconURL
            )

            VStack(
                alignment: .trailing,
                spacing: 4
            ) {
                Text(app.name)
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
                    .lineLimit(1)

                HStack(spacing: 7) {
                    if !app.version.isEmpty {
                        Text(
                            "v\(app.version)"
                        )
                    }

                    if !app.category.isEmpty {
                        Text(
                            app.category
                        )
                    }
                }
                .font(
                    .system(
                        size: 9,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            installButton(
                app
            )
        }
        .padding(11)
        .background(
            KindaTheme.cardBG,
            in:
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
        )
    }

    private func installButton(
        _ app: StoreApp
    ) -> some View {
        let downloading =
            activeDownloadID == app.id

        let value =
            downloadProgress[
                app.id
            ] ?? 0

        return Button {
            install(
                app
            )
        } label: {
            HStack(spacing: 5) {
                if downloading {
                    ProgressView(
                        value: value
                    )
                    .progressViewStyle(
                        .circular
                    )
                    .controlSize(
                        .small
                    )

                    Text(
                        "\(Int(value * 100))%"
                    )
                } else {
                    Text(
                        "تثبيت"
                    )
                }
            }
            .font(
                .system(
                    size: 11,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .primary
            )
            .padding(
                .horizontal,
                12
            )
            .frame(height: 32)
            .background(
                Color.primary.opacity(
                    0.09
                ),
                in: Capsule()
            )
        }
        .buttonStyle(
            .plain
        )
        .disabled(
            downloading
        )
    }

    private var nextButton: some View {
        Button {
            Task {
                await storeManager.loadNextPage()
            }
        } label: {
            HStack(spacing: 7) {
                if storeManager.isLoading {
                    ProgressView()
                        .controlSize(
                            .small
                        )
                }

                Text(
                    storeManager.isLoading
                        ? "جاري التحميل..."
                        : "التالي"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
            }
            .foregroundStyle(
                .primary
            )
            .frame(
                maxWidth: .infinity
            )
            .frame(height: 40)
            .background(
                .ultraThinMaterial,
                in: Capsule()
            )
        }
        .buttonStyle(
            .plain
        )
        .disabled(
            storeManager.isLoading
        )
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(
                systemName:
                    "square.grid.2x2"
            )
            .font(
                .system(
                    size: 27,
                    weight: .light
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                storeManager.isLoading
                    ? "جاري تحميل التطبيقات..."
                    : "لا توجد تطبيقات"
            )
            .font(
                .system(
                    size: 15,
                    weight: .semibold
                )
            )

            Text(
                "التطبيقات المعروضة هنا تأتي من لوحة التحكم فقط."
            )
            .font(
                .system(size: 11)
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 42)
    }

    // MARK: Install

    private func install(
        _ app: StoreApp
    ) {
        guard
            activeDownloadID == nil
        else {
            return
        }

        guard
            let url =
                URL(
                    string:
                        app.ipaURL.trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                )
        else {
            showError(
                "رابط IPA غير صالح."
            )
            return
        }

        let id =
            "FeatherManualDownload_\(UUID().uuidString)"

        activeDownloadID =
            app.id
        downloadProgress[
            app.id
        ] = 0

        let download =
            downloadManager.startDownload(
                from: url,
                id: id
            )

        Task {
            await watchDownload(
                download,
                app: app
            )
        }
    }

    private func watchDownload(
        _ download: Download,
        app: StoreApp
    ) async {
        while
            activeDownloadID == app.id
        {
            if
                let current =
                    downloadManager.getDownload(
                        by: download.id
                    )
            {
                await MainActor.run {
                    downloadProgress[
                        app.id
                    ] = current.overallProgress
                }

                if current.progress >= 0.999 {
                    break
                }
            } else {
                break
            }

            try? await Task.sleep(
                nanoseconds:
                    200_000_000
            )
        }

        // DownloadManager moves and extracts the package
        // into the existing Imported Core Data store.
        for _ in 0..<150 {
            if let imported =
                newestImported(
                    matching: app
                ) {
                activeDownloadID = nil
                downloadProgress[
                    app.id
                ] = nil
                selectedInstallUUID =
                    imported.uuid
                return
            }

            try? await Task.sleep(
                nanoseconds:
                    200_000_000
            )
        }

        await MainActor.run {
            activeDownloadID = nil
            downloadProgress[
                app.id
            ] = nil
        }
    }

    private func newestImported(
        matching app: StoreApp
    ) -> Imported? {
        importedApps.first {
            if
                let identifier =
                    $0.identifier,
                !app.bundleIdentifier.isEmpty,
                identifier ==
                    app.bundleIdentifier
            {
                return true
            }

            return
                $0.name?.localizedCaseInsensitiveCompare(
                    app.name
                ) == .orderedSame
        }
    }

    // MARK: File import

    private func handleFileImport(
        _ result:
            Result<
                [URL],
                Error
            >
    ) {
        switch result {
        case .success(
            let urls
        ):
            guard
                let url =
                    urls.first
            else {
                return
            }

            importFile(
                url
            )

        case .failure(
            let error
        ):
            showError(
                error.localizedDescription
            )
        }
    }

    private func importFile(
        _ url: URL
    ) {
        let accessed =
            url.startAccessingSecurityScopedResource()

        let id =
            "FeatherManualDownload_\(UUID().uuidString)"

        let download =
            downloadManager.startArchive(
                from: url,
                id: id
            )

        downloadManager.handlePachageFile(
            url: url,
            dl: download
        ) { error in
            if let error {
                showError(
                    "تعذر استيراد IPA: \(error.localizedDescription)"
                )
                return
            }

            Task { @MainActor in
                let uuid =
                    newestImportedFromURL(
                        url
                    )?.uuid

                if let uuid {
                    selectedInstallUUID =
                        uuid
                }

                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }

    private func newestImportedFromURL(
        _ url: URL
    ) -> Imported? {
        importedApps.first(
            where: {
                $0.source?.lastPathComponent ==
                    url.lastPathComponent
            }
        ) ?? importedApps.first(
            where: { _ in true }
        )
    }

    // MARK: URL import

    private var urlImportSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "رابط ملف IPA",
                        text: $ipaURL
                    )
                    .textInputAutocapitalization(
                        .never
                    )
                    .autocorrectionDisabled()
                    .keyboardType(
                        .URL
                    )
                }

                Section {
                    Button {
                        let value =
                            ipaURL.trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )

                        guard
                            let url =
                                URL(
                                    string:
                                        value
                                ),
                            let scheme =
                                url.scheme?.lowercased(),
                            scheme == "http" ||
                            scheme == "https"
                        else {
                            showError(
                                "رابط غير صالح."
                            )
                            return
                        }

                        showURLSheet =
                            false

                        let id =
                            "FeatherManualDownload_\(UUID().uuidString)"

                        let download =
                            downloadManager.startDownload(
                                from: url,
                                id: id
                            )

                        Task {
                            await watchURLDownload(
                                download
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(
                                "تنزيل وبدء التثبيت"
                            )
                            .font(
                                .system(
                                    size: 14,
                                    weight: .semibold
                                )
                            )
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(
                "استيراد IPA"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button(
                        "إلغاء"
                    ) {
                        showURLSheet =
                            false
                    }
                }
            }
        }
        .environment(
            \.layoutDirection,
            .rightToLeft
        )
    }

    private func watchURLDownload(
        _ download: Download
    ) async {
        while
            downloadManager.getDownload(
                by: download.id
            ) != nil
        {
            try? await Task.sleep(
                nanoseconds:
                    250_000_000
            )
        }

        for _ in 0..<150 {
            if let imported =
                importedApps.first(
                    where: { _ in true }
                )
            {
                selectedInstallUUID =
                    imported.uuid
                return
            }

            try? await Task.sleep(
                nanoseconds:
                    200_000_000
            )
        }
    }

    private func showError(
        _ message: String
    ) {
        UIAlertController.showAlertWithOk(
            title:
                "التثبيت",
            message:
                message
        )
    }
}
