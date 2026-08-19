//
//  HomeView.swift
//  Ksign
//
//  التطبيقات - الشاشة الرئيسية
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - Home View
struct HomeView: View {

    // MARK: Managers
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var storeManager = KindaStoreManager.shared

    // MARK: Presenting
    @State private var selectedInfoAppPresenting: AnyApp?
    @State private var selectedSigningAppPresenting: AnyApp?
    @State private var selectedInstallAppPresenting: AnyApp?
    @State private var selectedAppDylibsPresenting: AnyApp?

    @State private var isBulkSigningPresenting = false
    @State private var isBulkInstallingPresenting = false

    @State private var isImportingPresenting = false
    @State private var isDownloadingPresenting = false

    @State private var alertDownloadString = ""
    @State private var searchText = ""

    // 0 = التطبيقات المستوردة
    // 1 = التطبيقات الموقعة
    // 2 = المتجر (Lovable Cloud)
    @State private var selectedTab = 0

    // MARK: Edit Mode
    @State private var isEditMode: EditMode = .inactive
    @State private var selectedApps: Set<String> = []

    @Namespace private var namespace

    // MARK: Core Data

    @FetchRequest(
        entity: Signed.entity(),
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \Signed.date,
                ascending: false
            )
        ],
        animation: .snappy
    )
    private var signedApps: FetchedResults<Signed>

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

    // MARK: Filtered Apps

    private var filteredSignedApps: [Signed] {
        signedApps.filter { app in
            searchText.isEmpty ||
            (app.name?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var filteredImportedApps: [Imported] {
        importedApps.filter { app in
            searchText.isEmpty ||
            (app.name?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // MARK: Body

    var body: some View {
        NBNavigationView(.localized("الرئيسية")) {

            VStack(spacing: 0) {

                // MARK: App Type Picker

                Picker(
                    "",
                    selection: $selectedTab
                ) {
                    Text(
                        .localized("التطبيقات")
                    )
                    .tag(0)

                    Text(
                        .localized("الموقعة")
                    )
                    .tag(1)

                    Text(
                        .localized("المتجر")
                    )
                    .tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // MARK: Apps List

                NBListAdaptable {

                    if selectedTab == 2 {

                        // MARK: Store Section

                        NBSection(
                            .localized("المتجر"),
                            secondary: storeManager.filtered(searchText).count.description
                        ) {

                            ForEach(
                                storeManager.filtered(searchText)
                            ) { app in

                                StoreCellView(
                                    app: app
                                )
                            }
                        }

                    } else if selectedTab == 0 {

                        NBSection(
                            .localized("التطبيقات"),
                            secondary: filteredImportedApps.count.description
                        ) {

                            ForEach(
                                filteredImportedApps,
                                id: \.uuid
                            ) { app in

                                LibraryCellView(
                                    app: app,
                                    selectedInfoAppPresenting: $selectedInfoAppPresenting,
                                    selectedSigningAppPresenting: $selectedSigningAppPresenting,
                                    selectedInstallAppPresenting: $selectedInstallAppPresenting,
                                    selectedAppDylibsPresenting: $selectedAppDylibsPresenting,
                                    selectedApps: $selectedApps
                                )
                                .compatMatchedTransitionSource(
                                    id: app.uuid ?? "",
                                    ns: namespace
                                )
                            }
                        }

                    } else {

                        NBSection(
                            .localized("التطبيقات الموقعة"),
                            secondary: filteredSignedApps.count.description
                        ) {

                            ForEach(
                                filteredSignedApps,
                                id: \.uuid
                            ) { app in

                                LibraryCellView(
                                    app: app,
                                    selectedInfoAppPresenting: $selectedInfoAppPresenting,
                                    selectedSigningAppPresenting: $selectedSigningAppPresenting,
                                    selectedInstallAppPresenting: $selectedInstallAppPresenting,
                                    selectedAppDylibsPresenting: $selectedAppDylibsPresenting,
                                    selectedApps: $selectedApps
                                )
                                .compatMatchedTransitionSource(
                                    id: app.uuid ?? "",
                                    ns: namespace
                                )
                            }
                        }
                    }
                }
            }

            // MARK: Store Loading

            .task {

                if storeManager.apps.isEmpty {

                    await storeManager.load()
                }
            }
            .refreshable {

                await storeManager.load()
            }

            // MARK: Search

            .searchable(
                text: $searchText,
                placement: .platform()
            )

            // MARK: Empty State

            .overlay {

                let noImportedApps = filteredImportedApps.isEmpty
                let noSignedApps = filteredSignedApps.isEmpty

                if noImportedApps && noSignedApps && selectedTab != 2 {

                    if #available(iOS 17, *) {

                        ContentUnavailableView {

                            Label(
                                .localized("لا توجد تطبيقات"),
                                systemImage: "app.badge"
                            )

                        } description: {

                            Text(
                                .localized(
                                    "ابدأ باستيراد أول ملف IPA إلى KINDA."
                                )
                            )

                        } actions: {

                            Menu {

                                importActions()

                            } label: {

                                Text(
                                    .localized("استيراد")
                                )
                                .bg()
                            }
                        }
                    }
                }
            }

            // MARK: Toolbar

            .toolbar {

                // زر التعديل
                ToolbarItem(
                    placement: .topBarLeading
                ) {

                    EditButton()
                }

                // وضع التعديل
                if isEditMode.isEditing {

                    ToolbarItemGroup(
                        placement: .topBarTrailing
                    ) {

                        // Sign
                        if selectedTab == 0 {

                            Button {

                                isBulkSigningPresenting = true

                            } label: {

                                NBButton(
                                    .localized("Sign"),
                                    systemImage: "signature",
                                    style: .icon
                                )
                            }
                            .disabled(selectedApps.isEmpty)

                        }

                        // Install
                        else {

                            Button {

                                isBulkInstallingPresenting = true

                            } label: {

                                NBButton(
                                    .localized("Install"),
                                    systemImage: "square.and.arrow.down"
                                )
                            }
                            .disabled(selectedApps.isEmpty)
                        }

                        // Delete
                        Button {

                            bulkDeleteSelectedApps()

                        } label: {

                            NBButton(
                                .localized("Delete"),
                                systemImage: "trash",
                                style: .icon
                            )
                        }
                        .disabled(selectedApps.isEmpty)
                    }

                } else {

                    // إضافة / استيراد تطبيق
                    NBToolbarMenu(
                        systemImage: "plus",
                        style: .icon,
                        placement: .topBarTrailing
                    ) {

                        importActions()
                    }
                }
            }

            // MARK: Edit Mode

            .environment(
                \.editMode,
                $isEditMode
            )

            // MARK: App Info

            .sheet(
                item: $selectedInfoAppPresenting
            ) { app in

                LibraryInfoView(
                    app: app.base
                )
            }

            // MARK: Install

            .sheet(
                item: $selectedInstallAppPresenting
            ) { app in

                InstallPreviewView(
                    app: app.base,
                    isSharing: app.archive
                )
                .presentationDetents(
                    [.height(200)]
                )
                .presentationDragIndicator(
                    .visible
                )
            }

            // MARK: Signing

            .fullScreenCover(
                item: $selectedSigningAppPresenting
            ) { app in

                SigningView(
                    app: app.base,
                    signAndInstall: app.signAndInstall
                )
                .compatNavigationTransition(
                    id: app.base.uuid ?? "",
                    ns: namespace
                )
            }

            // MARK: Dylibs

            .fullScreenCover(
                item: $selectedAppDylibsPresenting
            ) { app in

                DylibsView(
                    app: app.base
                )
                .compatNavigationTransition(
                    id: app.base.uuid ?? "",
                    ns: namespace
                )
            }

            // MARK: Bulk Signing

            .fullScreenCover(
                isPresented: $isBulkSigningPresenting
            ) {

                BulkSigningView(
                    apps: selectedApps.compactMap { id in

                        (
                            importedApps.first(
                                where: {
                                    $0.uuid == id
                                }
                            ) as AppInfoPresentable?
                        )
                        ??
                        (
                            signedApps.first(
                                where: {
                                    $0.uuid == id
                                }
                            ) as AppInfoPresentable?
                        )
                    }
                )
                .compatNavigationTransition(
                    id: selectedApps.joined(
                        separator: ","
                    ),
                    ns: namespace
                )
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSNotification.Name(
                            "ksign.bulkSigningFinished"
                        )
                    )
                ) { _ in

                    selectedTab = 1
                }
            }

            // MARK: Bulk Installing

            .sheet(
                isPresented: $isBulkInstallingPresenting
            ) {

                BulkInstallPreviewView(
                    apps: selectedApps.compactMap { id in

                        (
                            importedApps.first(
                                where: {
                                    $0.uuid == id
                                }
                            ) as AppInfoPresentable?
                        )
                        ??
                        (
                            signedApps.first(
                                where: {
                                    $0.uuid == id
                                }
                            ) as AppInfoPresentable?
                        )
                    }
                )
                .presentationDetents(
                    [
                        .medium,
                        .large
                    ]
                )
                .presentationDragIndicator(
                    .visible
                )
            }

            // MARK: Import IPA

            .sheet(
                isPresented: $isImportingPresenting
            ) {

                FileImporterRepresentableView(
                    allowedContentTypes: [
                        .ipa,
                        .tipa
                    ],
                    allowsMultipleSelection: true,
                    onDocumentsPicked: { urls in

                        guard !urls.isEmpty else {
                            return
                        }

                        for ipaURL in urls {

                            let id =
                                "FeatherManualDownload_\(UUID().uuidString)"

                            let download =
                                downloadManager.startArchive(
                                    from: ipaURL,
                                    id: id
                                )

                            downloadManager.handlePachageFile(
                                url: ipaURL,
                                dl: download
                            ) { error in

                                if error != nil {

                                    UIAlertController.showAlertWithOk(
                                        title: .localized("Error"),
                                        message: .localized(
                                            "Whoops!, something went wrong when extracting the file. \nMaybe try switching the extraction library in the settings?"
                                        )
                                    )
                                }
                            }
                        }
                    }
                )
            }

            // MARK: Import From URL

            .alert(
                .localized("Import from URL"),
                isPresented: $isDownloadingPresenting
            ) {

                TextField(
                    .localized("URL"),
                    text: $alertDownloadString
                )

                Button(
                    .localized("Cancel"),
                    role: .cancel
                ) {

                    alertDownloadString = ""
                }

                Button(
                    .localized("OK")
                ) {

                    guard
                        let url = URL(
                            string: alertDownloadString
                        )
                    else {
                        return
                    }

                    _ = downloadManager.startDownload(
                        from: url,
                        id:
                            "FeatherManualDownload_\(UUID().uuidString)"
                    )

                    alertDownloadString = ""
                }

            }

            // MARK: Sign & Install Notification

            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name(
                        "feather.installApp"
                    )
                )
            ) { _ in

                if let app = signedApps.first {

                    selectedInstallAppPresenting =
                        AnyApp(
                            base: app
                        )
                }
            }
        }

        // MARK: Edit Mode Cleanup

        .onChange(
            of: isEditMode
        ) { state in

            if !state.isEditing {

                DispatchQueue.main.async {

                    withAnimation {

                        selectedApps.removeAll()
                    }
                }
            }
        }
    }
}

// MARK: - Import Actions

extension HomeView {

    @ViewBuilder
    private func importActions() -> some View {

        Button(
            .localized("Import from Files"),
            systemImage: "folder"
        ) {

            isImportingPresenting = true
        }

        Button(
            .localized("Import from URL"),
            systemImage: "globe"
        ) {

            isDownloadingPresenting = true
        }
    }
}

// MARK: - Bulk Delete

extension HomeView {

    private func bulkDeleteSelectedApps() {

        let appsToDelete = selectedApps

        withAnimation(
            .easeInOut(
                duration: 0.5
            )
        ) {

            for appUUID in appsToDelete {

                if let signedApp =
                    signedApps.first(
                        where: {
                            $0.uuid == appUUID
                        }
                    ) {

                    Storage.shared.deleteApp(
                        for: signedApp
                    )

                } else if let importedApp =
                            importedApps.first(
                                where: {
                                    $0.uuid == appUUID
                                }
                            ) {

                    Storage.shared.deleteApp(
                        for: importedApp
                    )
                }
            }
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.3
        ) {

            selectedApps.removeAll()
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case bundleId = "bundle_id"
        case appDescription = "description"
        case category
        case iconURL = "icon_url"
        case ipaURL = "ipa_url"
    }
}

// MARK: - Store Manager

@MainActor
final class KindaStoreManager: ObservableObject {

    static let shared = KindaStoreManager()

    // بيانات الاتصال بلوحة التحكم (Lovable Cloud)
    private let baseURL = "https://ibskoyypugseeixzntyt.supabase.co"
    private let apiKey = "sb_publishable_McRq3FTx_r7pL2PbGk8YBA_mMnJmtFm"

    @Published var apps: [StoreApp] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    func filtered(_ searchText: String) -> [StoreApp] {

        guard !searchText.isEmpty else {
            return apps
        }

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

        guard
            let url = URL(
                string: "\(baseURL)/rest/v1/store_apps?select=*&order=created_at.desc"
            )
        else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {

            let (data, _) = try await URLSession.shared.data(for: request)
            apps = try JSONDecoder().decode([StoreApp].self, from: data)

        } catch {

            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Store Cell

struct StoreCellView: View {

    let app: StoreApp

    @StateObject private var downloadManager = DownloadManager.shared

    var body: some View {

        HStack(spacing: 12) {

            AsyncImage(
                url: URL(string: app.iconURL)
            ) { image in

                image
                    .resizable()
                    .scaledToFill()

            } placeholder: {

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 52, height: 52)
            .clipShape(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 2) {

                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(app.category) • \(app.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !app.appDescription.isEmpty {

                    Text(app.appDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {

                download()

            } label: {

                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func download() {

        guard
            let url = URL(string: app.ipaURL)
        else {
            return
        }

        _ = downloadManager.startDownload(
            from: url,
            id: "KindaStore_\(app.id)"
        )
    }
}
