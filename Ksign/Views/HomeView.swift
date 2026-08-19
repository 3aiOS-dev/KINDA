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
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // MARK: Apps List

                NBListAdaptable {

                    if selectedTab == 0 {

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

            // MARK: Search

            .searchable(
                text: $searchText,
                placement: .platform()
            )

            // MARK: Empty State

            .overlay {

                let noImportedApps = filteredImportedApps.isEmpty
                let noSignedApps = filteredSignedApps.isEmpty

                if noImportedApps && noSignedApps {

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
