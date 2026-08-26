//
//  HomeView.swift
//  KINDA
//
//  الرئيسية:
//  - التطبيقات من لوحة التحكم فقط.
//  - لا توجد مصادر خارجية.
//  - لا يوجد تبويب توقيع.
//  - الضغط على التطبيق يفتح التفاصيل.
//  - زر تثبيت يبدأ التثبيت مباشرة بدون فتح تبويب آخر.
//  - استيراد IPA من الملفات أو من الرابط موجود في الرئيسية.
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
    @State private var selectedApp: StoreApp?
    @State private var showFileImporter = false
    @State private var showURLImporter = false
    @State private var ipaURL = ""
    @State private var showURLSheet = false
    @State private var isImporting = false

    private let pageSize = 50

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
                    LazyVStack(spacing: 14) {
                        header
                        importActions

                        categoryBar

                        if filteredApps.isEmpty {
                            emptyState
                        } else {
                            appsList
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
            .environment(
                \.layoutDirection,
                .rightToLeft
            )
        }
        .environment(
            \.layoutDirection,
            .rightToLeft
        )
        .task {
            if storeManager.apps.isEmpty {
                await storeManager.load()
            }
        }
        .sheet(item: $selectedApp) { app in
            StoreAppDetailsView(
                app: app
            )
            .presentationDetents(
                [.medium, .large]
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showURLSheet) {
            urlImportSheet
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                .item
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 5) {
            Text("الرئيسية")
                .font(
                    .system(
                        size: 21,
                        weight: .bold
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
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
        .padding(.top, 18)
    }

    // MARK: - Import

    private var importActions: some View {
        HStack(spacing: 10) {
            importButton(
                title: "من الملفات",
                subtitle: "IPA",
                icon: "folder.fill"
            ) {
                showFileImporter = true
            }

            importButton(
                title: "من الرابط",
                subtitle: "IPA",
                icon: "link"
            ) {
                ipaURL = ""
                showURLSheet = true
            }
        }
    }

    private func importButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .frame(
                        width: 38,
                        height: 38
                    )
                    .background(
                        Color.primary.opacity(0.08),
                        in: RoundedRectangle(
                            cornerRadius: 11,
                            style: .continuous
                        )
                    )

                VStack(
                    alignment: .trailing,
                    spacing: 2
                ) {
                    Text(title)
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )

                    Text(subtitle)
                        .font(
                            .system(
                                size: 9,
                                weight: .medium,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 62)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
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

    private var urlImportSheet: some View {
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
                        "ضع رابط مباشر لملف IPA."
                    )
                }

                Section {
                    Button {
                        let value =
                            ipaURL.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                        guard
                            let url = URL(
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
                            await importFromURL(
                                url
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("استيراد")
                                .font(
                                    .system(
                                        size: 15,
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
            .navigationTitle("استيراد من الرابط")
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

    // MARK: - Categories

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
                                selectedCategory =
                                    category
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
                                    .frame(height: 30)
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
                .environment(
                    \.layoutDirection,
                    .rightToLeft
                )
            }
        }
    }

    // MARK: - Apps

    private var appsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredApps) { app in
                appRow(app)
            }
        }
    }

    private func appRow(
        _ app: StoreApp
    ) -> some View {
        Button {
            selectedApp = app
        } label: {
            HStack(spacing: 12) {
                StoreIconView(
                    urlString: app.iconURL,
                    size: 52
                )

                VStack(
                    alignment: .trailing,
                    spacing: 4
                ) {
                    Text(app.name)
                        .font(
                            .system(
                                size: 15,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 7) {
                        if !app.version.isEmpty {
                            Text(
                                "v\(app.version)"
                            )
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

                Image(
                    systemName: "chevron.left"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(
                    cornerRadius: 19,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 19,
                    style: .continuous
                )
                .stroke(
                    Color.primary.opacity(0.055),
                    lineWidth: 0.7
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var nextButton: some View {
        Button {
            Task {
                await storeManager.loadNextServerPage()
            }
        } label: {
            HStack(spacing: 8) {
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
            .frame(height: 42)
            .background(
                .ultraThinMaterial,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(
            storeManager.isLoading
        )
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(
                systemName:
                    searchText.isEmpty
                    ? "square.grid.2x2"
                    : "magnifyingglass"
            )
            .font(
                .system(
                    size: 27,
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
            .font(
                .system(
                    size: 11
                )
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 45)
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
                await importFromFile(
                    url
                )
            }

        case .failure(let error):
            print(
                "IPA file import error: \(error.localizedDescription)"
            )
        }
    }

    private func importFromFile(
        _ url: URL
    ) async {
        isImporting = true
        defer {
            isImporting = false
        }

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
                        UUID().uuidString
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

            await presentImportedFile(
                destination
            )
        } catch {
            UIAlertController.showAlertWithOk(
                title: "استيراد IPA",
                message:
                    "تعذر قراءة الملف: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - URL import

    private func importFromURL(
        _ url: URL
    ) async {
        isImporting = true
        defer {
            isImporting = false
        }

        do {
            var request =
                URLRequest(url: url)

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

            let fileExtension =
                url.pathExtension.isEmpty
                    ? "ipa"
                    : url.pathExtension

            let fileURL =
                FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "Imported-\(UUID().uuidString)"
                    )
                    .appendingPathExtension(
                        fileExtension
                    )

            try data.write(
                to: fileURL,
                options: .atomic
            )

            await presentImportedFile(
                fileURL
            )
        } catch {
            UIAlertController.showAlertWithOk(
                title: "استيراد من الرابط",
                message:
                    "تعذر تنزيل ملف IPA: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Direct installation

    private func presentImportedFile(
        _ url: URL
    ) async {
        // Notification consumed by the existing
        // InstallPreviewView flow.
        NotificationCenter.default.post(
            name: .kindaOpenInstallPreview,
            object: nil,
            userInfo: [
                "url": url
            ]
        )
    }
}

enum ImportError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "رابط الملف لم يرجع ملف IPA صالحاً."
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let kindaOpenInstallPreview =
        Notification.Name(
            "kinda.openInstallPreview"
        )
}
