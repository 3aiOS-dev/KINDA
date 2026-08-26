//
//  HomeView.swift
//  KINDA
//
//  الرئيسية فقط:
//  - التطبيقات من لوحة التحكم.
//  - زر تثبيت مباشر.
//  - بعد اكتمال التنزيل تفتح شاشة التثبيت مباشرة.
//  - استيراد IPA من الملفات أو الرابط.
//  - لا توجد شاشة تفاصيل.
//  - لا يوجد تبويب توقيع.
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers
import UIKit

struct HomeView: View {
    @StateObject private var storeManager = KindaStoreManager.shared
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var searchText = ""
    @State private var selectedCategory = "الكل"
    @State private var showFileImporter = false
    @State private var showURLSheet = false
    @State private var ipaURL = ""
    @State private var installingAppID: String?
    @State private var progress: [String: Double] = [:]

    private var filteredApps: [StoreApp] {
        storeManager.filtered(
            searchText,
            source: "لوحة التحكم",
            category: selectedCategory
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindaTheme.pageBG
                    .ignoresSafeArea()

                KindaGridBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        header
                        importActions
                        searchBar
                        categoryBar

                        if filteredApps.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredApps) { app in
                                appRow(app)
                            }
                        }

                        if storeManager.hasMoreServerPages {
                            nextButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 35)
                }
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
        .sheet(isPresented: $showURLSheet) {
            urlSheet
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .kindaOpenInstallPreview
            )
        ) { notification in
            guard
                let url =
                    notification.userInfo?["url"] as? URL
            else {
                return
            }

            openInstallPreview(url: url)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("الرئيسية")
                .font(
                    .system(
                        size: 21,
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
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .center
        )
        .padding(.top, 18)
    }

    private var importActions: some View {
        HStack(spacing: 9) {
            actionButton(
                title: "استيراد من الملفات",
                icon: "folder.fill"
            ) {
                showFileImporter = true
            }

            actionButton(
                title: "استيراد من الرابط",
                icon: "link"
            ) {
                ipaURL = ""
                showURLSheet = true
            }
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
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
            .foregroundStyle(.primary)
            .frame(
                maxWidth: .infinity
            )
            .frame(height: 42)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    Color.primary.opacity(0.07),
                    lineWidth: 0.7
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "البحث عن تطبيق",
                text: $searchText
            )
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }

    private var categoryBar: some View {
        Group {
            if storeManager.availableCategories.count > 1 {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(spacing: 7) {
                        ForEach(
                            storeManager.availableCategories,
                            id: \.self
                        ) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(
                                        .system(
                                            size: 11,
                                            weight: .semibold
                                        )
                                    )
                                    .foregroundStyle(
                                        selectedCategory == category
                                            ? .primary
                                            : .secondary
                                    )
                                    .padding(
                                        .horizontal,
                                        12
                                    )
                                    .frame(height: 29)
                                    .background(
                                        selectedCategory == category
                                            ? Color.primary.opacity(0.12)
                                            : Color.secondary.opacity(0.07),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func appRow(
        _ app: StoreApp
    ) -> some View {
        HStack(spacing: 11) {
            StoreIconView(
                urlString: app.iconURL,
                size: 50
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
                        Text("v\(app.version)")
                    }

                    if !app.category.isEmpty {
                        Text(app.category)
                    }
                }
                .font(
                    .system(
                        size: 9,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.secondary)
            }

            Spacer()

            installButton(app)
        }
        .padding(11)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.055),
                lineWidth: 0.7
            )
        }
    }

    private func installButton(
        _ app: StoreApp
    ) -> some View {
        let isDownloading =
            installingAppID == app.id

        let value =
            progress[app.id] ?? 0

        return Button {
            startDirectInstall(app)
        } label: {
            HStack(spacing: 6) {
                if isDownloading {
                    ZStack {
                        Circle()
                            .stroke(
                                Color.secondary.opacity(0.25),
                                lineWidth: 2
                            )
                            .frame(
                                width: 14,
                                height: 14
                            )

                        Circle()
                            .trim(
                                from: 0,
                                to: max(
                                    0.03,
                                    value
                                )
                            )
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(
                                    lineWidth: 2,
                                    lineCap: .round
                                )
                            )
                            .frame(
                                width: 14,
                                height: 14
                            )
                            .rotationEffect(
                                .degrees(-90)
                            )
                    }

                    Text(
                        "\(Int(value * 100))%"
                    )
                } else {
                    Text("تثبيت")
                }
            }
            .font(
                .system(
                    size: 11,
                    weight: .semibold
                )
            )
            .foregroundStyle(.primary)
            .padding(
                .horizontal,
                12
            )
            .frame(height: 32)
            .background(
                Color.primary.opacity(0.09),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
    }

    private var nextButton: some View {
        Button {
            Task {
                await storeManager.loadNextServerPage()
            }
        } label: {
            HStack(spacing: 7) {
                if storeManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(
                    storeManager.isLoading
                        ? "جاري التحميل..."
                        : "تحميل المزيد"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
            }
            .foregroundStyle(.primary)
            .frame(
                maxWidth: .infinity
            )
            .frame(height: 40)
            .background(
                .ultraThinMaterial,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isLoading)
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(
                systemName: "square.grid.2x2"
            )
            .font(
                .system(
                    size: 28,
                    weight: .light
                )
            )
            .foregroundStyle(.secondary)

            Text("لا توجد تطبيقات")
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )

            Text(
                "أضف التطبيقات من لوحة التحكم لتظهر هنا."
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 45)
    }

    // MARK: - Direct installation from dashboard

    private func startDirectInstall(
        _ app: StoreApp
    ) {
        guard
            installingAppID == nil
        else {
            return
        }

        guard
            let url =
                URL(
                    string:
                        app.ipaURL.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                )
        else {
            showError(
                title: "التثبيت",
                message: "رابط IPA غير صالح."
            )
            return
        }

        installingAppID = app.id
        progress[app.id] = 0

        StoreNotificationManager.postStarted(
            appName: app.name,
            version: app.version
        )

        Task {
            await downloadAndOpenInstaller(
                url: url,
                appID: app.id,
                appName: app.name
            )
        }
    }

    private func downloadAndOpenInstaller(
        url: URL,
        appID: String,
        appName: String
    ) async {
        do {
            let downloadID =
                "HomeDirect-\(appID)-\(UUID().uuidString)"

            let download =
                downloadManager.startDownload(
                    from: url,
                    id: downloadID
                )

            while true {
                try Task.checkCancellation()

                guard
                    let current =
                        downloadManager.getDownload(
                            by: downloadID
                        )
                else {
                    break
                }

                progress[appID] =
                    current.progress

                if current.totalBytes > 0,
                   current.progress >= 0.999 {
                    break
                }

                try await Task.sleep(
                    nanoseconds:
                        250_000_000
                )
            }

            // Give the existing importer/install pipeline
            // a moment to register the downloaded IPA.
            try await Task.sleep(
                nanoseconds:
                    350_000_000
            )

            if let imported =
                findImportedApp(
                    appID: appID,
                    appName: appName
                ) {
                await MainActor.run {
                    installingAppID = nil
                    progress[appID] = nil

                    openInstallPreview(
                        imported: imported
                    )
                }
                return
            }

            // Fallback: notify the existing installation
            // pipeline with the download identifier.
            NotificationCenter.default.post(
                name: .kindaOpenInstallPreview,
                object: nil,
                userInfo: [
                    "downloadID": downloadID,
                    "appID": appID
                ]
            )

            await MainActor.run {
                installingAppID = nil
                progress[appID] = nil
            }
        } catch {
            await MainActor.run {
                installingAppID = nil
                progress[appID] = nil

                showError(
                    title: "التثبيت",
                    message:
                        "تعذر تنزيل \(appName): \(error.localizedDescription)"
                )
            }
        }
    }

    private func findImportedApp(
        appID: String,
        appName: String
    ) -> Imported? {
        let request =
            Imported.fetchRequest()

        request.fetchLimit = 20

        guard
            let values =
                try? PersistenceController.shared.container
                    .viewContext
                    .fetch(request)
        else {
            return nil
        }

        return values.first {
            guard
                let name = $0.name
            else {
                return false
            }

            return name.localizedCaseInsensitiveCompare(
                appName
            ) == .orderedSame
        }
    }

    private func openInstallPreview(
        imported: Imported
    ) {
        NotificationCenter.default.post(
            name: .kindaOpenInstallPreview,
            object: nil,
            userInfo: [
                "imported": imported
            ]
        )
    }

    // MARK: - File import

    private func handleFileImport(
        _ result:
            Result<
                [URL],
                Error
            >
    ) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }

            Task {
                await importIPAFile(
                    url
                )
            }

        case .failure(let error):
            showError(
                title: "استيراد",
                message:
                    error.localizedDescription
            )
        }
    }

    private func importIPAFile(
        _ url: URL
    ) async {
        let accessed =
            url.startAccessingSecurityScopedResource()

        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let destination =
                FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "Imported-\(UUID().uuidString)"
                    )
                    .appendingPathExtension(
                        url.pathExtension.isEmpty
                            ? "ipa"
                            : url.pathExtension
                    )

            try FileManager.default.copyItem(
                at: url,
                to: destination
            )

            NotificationCenter.default.post(
                name: .kindaOpenInstallPreview,
                object: nil,
                userInfo: [
                    "url": destination
                ]
            )
        } catch {
            showError(
                title: "استيراد IPA",
                message:
                    error.localizedDescription
            )
        }
    }

    // MARK: - URL import

    private var urlSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "رابط ملف IPA",
                        text: $ipaURL
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                } footer: {
                    Text(
                        "يجب أن يكون الرابط رابط تنزيل لملف IPA."
                    )
                }

                Section {
                    Button {
                        let value =
                            ipaURL.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                        guard
                            let url =
                                URL(
                                    string: value
                                ),
                            let scheme =
                                url.scheme?.lowercased(),
                            scheme == "http" ||
                            scheme == "https"
                        else {
                            return
                        }

                        showURLSheet = false

                        Task {
                            await importIPAFromURL(
                                url
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("تنزيل وبدء التثبيت")
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .semibold
                                    )
                                )
                            Spacer()
                        }
                    }
                    .disabled(
                        ipaURL
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
            .navigationTitle("استيراد IPA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("إلغاء") {
                        showURLSheet = false
                    }
                }
            }
        }
        .environment(
            \.layoutDirection,
            .rightToLeft
        )
    }

    private func importIPAFromURL(
        _ url: URL
    ) async {
        do {
            var request =
                URLRequest(
                    url: url
                )

            request.timeoutInterval = 60
            request.cachePolicy =
                .reloadIgnoringLocalCacheData

            let (
                data,
                response
            ) =
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
                throw ImportError.invalidResponse
            }

            let destination =
                FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "Imported-\(UUID().uuidString)"
                    )
                    .appendingPathExtension(
                        url.pathExtension.isEmpty
                            ? "ipa"
                            : url.pathExtension
                    )

            try data.write(
                to: destination,
                options: .atomic
            )

            NotificationCenter.default.post(
                name: .kindaOpenInstallPreview,
                object: nil,
                userInfo: [
                    "url": destination
                ]
            )
        } catch {
            showError(
                title: "استيراد IPA",
                message:
                    error.localizedDescription
            )
        }
    }

    private func openInstallPreview(
        url: URL
    ) {
        NotificationCenter.default.post(
            name: .kindaOpenInstallPreview,
            object: nil,
            userInfo: [
                "url": url
            ]
        )
    }

    private func showError(
        title: String,
        message: String
    ) {
        UIAlertController.showAlertWithOk(
            title: title,
            message: message
        )
    }
}

// MARK: - Shared notification

extension Notification.Name {
    static let kindaOpenInstallPreview =
        Notification.Name(
            "kinda.openInstallPreview"
        )
}

enum ImportError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "الرابط لم يرجع ملف IPA صالحاً."
        }
    }
}
