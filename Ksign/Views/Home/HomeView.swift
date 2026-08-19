//
//  HomeView.swift
//  KINDA
//

import SwiftUI
import CoreData
import NimbleViews

struct HomeView: View {

    // MARK: - Managers

    @StateObject var downloadManager = DownloadManager.shared

    // MARK: - Home State

    @State private var _searchText = ""

    @State private var _selectedInfoAppPresenting: AnyApp?
    @State private var _selectedSigningAppPresenting: AnyApp?
    @State private var _selectedInstallAppPresenting: AnyApp?
    @State private var _selectedAppDylibsPresenting: AnyApp?

    @State private var _isBulkSigningPresenting = false
    @State private var _isBulkInstallingPresenting = false

    @State private var _isImportingPresenting = false
    @State private var _isDownloadingPresenting = false

    @State private var _alertDownloadString = ""

    // MARK: - Edit Mode

    @State private var _isEditMode: EditMode = .inactive
    @State private var _selectedApps: Set<String> = []

    @Namespace private var _namespace

    // MARK: - Fetch

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
    private var _signedApps: FetchedResults<Signed>

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
    private var _importedApps: FetchedResults<Imported>

    // MARK: - Filtered Apps

    private var _filteredSignedApps: [Signed] {
        _signedApps.filter {
            _searchText.isEmpty ||
            (($0.value(forKey: "name") as? String)?
                .localizedCaseInsensitiveContains(_searchText) ?? false)
        }
    }

    private var _filteredImportedApps: [Imported] {
        _importedApps.filter {
            _searchText.isEmpty ||
            (($0.value(forKey: "name") as? String)?
                .localizedCaseInsensitiveContains(_searchText) ?? false)
        }
    }

    private var _appsCount: Int {
        _importedApps.count + _signedApps.count
    }

    // MARK: - Body

    var body: some View {

        NBNavigationView(.localized("Home")) {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 20
                ) {

                    // MARK: Banner

                    _homeBanner

                    // MARK: Quick Actions

                    _quickActions

                    // MARK: Applications

                    _applicationsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(
                Color(uiColor: .systemGroupedBackground)
            )
            .searchable(
                text: $_searchText,
                placement: .platform(),
                prompt: .localized("Search")
            )

            // MARK: Toolbar

            .toolbar {

                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    EditButton()
                }

                if _isEditMode.isEditing {

                    ToolbarItemGroup(
                        placement: .topBarTrailing
                    ) {

                        Button {
                            _selectAllApps()
                        } label: {
                            Image(systemName: "checklist")
                        }

                        Button {
                            _bulkDeleteSelectedApps()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(
                            _selectedApps.isEmpty
                        )
                    }

                } else {

                    ToolbarItem(
                        placement: .topBarTrailing
                    ) {

                        NBToolbarMenu(
                            systemImage: "plus",
                            style: .icon,
                            placement: .topBarTrailing
                        ) {
                            _importActions()
                        }
                    }
                }
            }

            .environment(
                \.editMode,
                $_isEditMode
            )

            // MARK: App Info

            .sheet(
                item: $_selectedInfoAppPresenting
            ) { app in

                LibraryInfoView(
                    app: app.base
                )
            }

            // MARK: Install

            .sheet(
                item: $_selectedInstallAppPresenting
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
                item: $_selectedSigningAppPresenting
            ) { app in

                SigningView(
                    app: app.base,
                    signAndInstall: app.signAndInstall
                )
                .compatNavigationTransition(
                    id: app.base.uuid ?? "",
                    ns: _namespace
                )
            }

            // MARK: Dylibs

            .fullScreenCover(
                item: $_selectedAppDylibsPresenting
            ) { app in

                DylibsView(
                    app: app.base
                )
                .compatNavigationTransition(
                    id: app.base.uuid ?? "",
                    ns: _namespace
                )
            }

            // MARK: Bulk Signing

            .fullScreenCover(
                isPresented: $_isBulkSigningPresenting
            ) {

                BulkSigningView(
                    apps: _selectedApps.compactMap { id in

                        (_importedApps.first(
                            where: { $0.uuid == id }
                        ) as AppInfoPresentable?)

                        ??

                        (_signedApps.first(
                            where: { $0.uuid == id }
                        ) as AppInfoPresentable?)
                    }
                )
                .compatNavigationTransition(
                    id: _selectedApps.joined(
                        separator: ","
                    ),
                    ns: _namespace
                )
            }

            // MARK: Bulk Install

            .sheet(
                isPresented: $_isBulkInstallingPresenting
            ) {

                BulkInstallPreviewView(
                    apps: _selectedApps.compactMap { id in

                        (_importedApps.first(
                            where: { $0.uuid == id }
                        ) as AppInfoPresentable?)

                        ??

                        (_signedApps.first(
                            where: { $0.uuid == id }
                        ) as AppInfoPresentable?)
                    }
                )
                .presentationDetents(
                    [.medium, .large]
                )
                .presentationDragIndicator(
                    .visible
                )
            }

            // MARK: File Import

            .sheet(
                isPresented: $_isImportingPresenting
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
                                "KindaManualDownload_\(UUID().uuidString)"

                            let dl =
                                downloadManager.startArchive(
                                    from: ipaURL,
                                    id: id
                                )

                            downloadManager.handlePachageFile(
                                url: ipaURL,
                                dl: dl
                            ) { error in

                                if error != nil {

                                    UIAlertController.showAlertWithOk(
                                        title: .localized("Error"),
                                        message: .localized(
                                            "Whoops!, something went wrong when extracting the file."
                                        )
                                    )
                                }
                            }
                        }
                    }
                )
            }

            // MARK: URL Import

            .alert(
                .localized("Import from URL"),
                isPresented: $_isDownloadingPresenting
            ) {

                TextField(
                    .localized("URL"),
                    text: $_alertDownloadString
                )

                Button(
                    .localized("Cancel"),
                    role: .cancel
                ) {

                    _alertDownloadString = ""
                }

                Button(
                    .localized("OK")
                ) {

                    guard
                        let url = URL(
                            string: _alertDownloadString
                        )
                    else {
                        return
                    }

                    _ = downloadManager.startDownload(
                        from: url,
                        id:
                            "KindaManualDownload_\(UUID().uuidString)"
                    )

                    _alertDownloadString = ""
                }
            }

            // MARK: Install Notification

            .onReceive(
                NotificationCenter.default.publisher(
                    for:
                        NSNotification.Name(
                            "feather.installApp"
                        )
                )
            ) { _ in

                if let app = _signedApps.first {

                    _selectedInstallAppPresenting =
                        AnyApp(
                            base: app
                        )
                }
            }

            // MARK: Edit Mode

            .onChange(
                of: _isEditMode
            ) { state in

                if !state.isEditing {

                    DispatchQueue.main.async {

                        withAnimation {

                            _selectedApps.removeAll()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Home Banner

    private var _homeBanner: some View {

        ZStack(
            alignment: .bottomLeading
        ) {

            RoundedRectangle(
                cornerRadius: 24
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.95),
                        Color.accentColor.opacity(0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(
                height: 190
            )

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                Image(
                    systemName:
                        "square.grid.2x2.fill"
                )
                .font(
                    .system(
                        size: 34,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)

                Text(
                    .localized("Welcome")
                )
                .font(
                    .largeTitle.bold()
                )
                .foregroundStyle(.white)

                Text(
                    .localized(
                        "Your Apps In One Place"
                    )
                )
                .font(.headline)
                .foregroundStyle(
                    .white.opacity(0.9)
                )

                Text(
                    "\(self._appsCount) " +
                    .localized("Apps")
                )
                .font(.subheadline)
                .foregroundStyle(
                    .white.opacity(0.8)
                )
            }
            .padding(22)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24
            )
        )
        .shadow(
            color: .black.opacity(0.08),
            radius: 12,
            y: 5
        )
    }

    // MARK: - Quick Actions

    private var _quickActions: some View {

        HStack(spacing: 12) {

            _quickAction(
                title: .localized("Import"),
                icon: "square.and.arrow.down"
            ) {
                _isImportingPresenting = true
            }

            _quickAction(
                title: .localized("From URL"),
                icon: "link"
            ) {
                _isDownloadingPresenting = true
            }

            _quickAction(
                title: .localized("Library"),
                icon: "square.grid.2x2"
            ) {
                NotificationCenter.default.post(
                    name:
                        NSNotification.Name(
                            "kinda.openLibrary"
                        ),
                    object: nil
                )
            }
        }
    }

    private func _quickAction(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(
            action: action
        ) {

            VStack(spacing: 8) {

                Image(
                    systemName: icon
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(
                maxWidth: .infinity
            )
            .frame(height: 70)
            .background(
                Color(
                    uiColor:
                        .secondarySystemGroupedBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Applications

    private var _applicationsSection: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Text(
                    .localized("Applications")
                )
                .font(.title2.bold())

                Spacer()

                Text(
                    "\(self._appsCount)"
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
            }

            if
                _filteredImportedApps.isEmpty,
                _filteredSignedApps.isEmpty
            {

                _emptyAppsView

            } else {

                LazyVStack(
                    spacing: 10
                ) {

                    if !_filteredImportedApps.isEmpty {

                        NBSection(
                            .localized(
                                "Downloaded Apps"
                            ),
                            secondary:
                                _filteredImportedApps
                                    .count
                                    .description
                        ) {

                            ForEach(
                                _filteredImportedApps,
                                id: \.uuid
                            ) { app in

                                LibraryCellView(
                                    app: app,
                                    selectedInfoAppPresenting:
                                        $_selectedInfoAppPresenting,
                                    selectedSigningAppPresenting:
                                        $_selectedSigningAppPresenting,
                                    selectedInstallAppPresenting:
                                        $_selectedInstallAppPresenting,
                                    selectedAppDylibsPresenting:
                                        $_selectedAppDylibsPresenting,
                                    selectedApps:
                                        $_selectedApps
                                )
                                .compatMatchedTransitionSource(
                                    id: app.uuid ?? "",
                                    ns: _namespace
                                )
                            }
                        }
                    }

                    if !_filteredSignedApps.isEmpty {

                        NBSection(
                            .localized(
                                "Signed Apps"
                            ),
                            secondary:
                                _filteredSignedApps
                                    .count
                                    .description
                        ) {

                            ForEach(
                                _filteredSignedApps,
                                id: \.uuid
                            ) { app in

                                LibraryCellView(
                                    app: app,
                                    selectedInfoAppPresenting:
                                        $_selectedInfoAppPresenting,
                                    selectedSigningAppPresenting:
                                        $_selectedSigningAppPresenting,
                                    selectedInstallAppPresenting:
                                        $_selectedInstallAppPresenting,
                                    selectedAppDylibsPresenting:
                                        $_selectedAppDylibsPresenting,
                                    selectedApps:
                                        $_selectedApps
                                )
                                .compatMatchedTransitionSource(
                                    id: app.uuid ?? "",
                                    ns: _namespace
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var _emptyAppsView: some View {

        VStack(
            spacing: 14
        ) {

            Image(
                systemName:
                    "square.grid.2x2"
            )
            .font(
                .system(
                    size: 42
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                .localized("No Apps")
            )
            .font(.headline)

            Text(
                .localized(
                    "Get started by importing your first IPA file."
                )
            )
            .font(.subheadline)
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )

            Button {

                _isImportingPresenting = true

            } label: {

                Text(
                    .localized("Import")
                )
                .bg()
            }
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .vertical,
            35
        )
    }

    // MARK: - Import Actions

    @ViewBuilder
    private func _importActions() -> some View {

        Button(
            .localized("Import from Files"),
            systemImage: "folder"
        ) {

            _isImportingPresenting = true
        }

        Button(
            .localized("Import from URL"),
            systemImage: "globe"
        ) {

            _isDownloadingPresenting = true
        }
    }

    // MARK: - Select All

    private func _selectAllApps() {

        let allIDs =
            _importedApps.compactMap {
                $0.uuid
            }
            +
            _signedApps.compactMap {
                $0.uuid
            }

        if _selectedApps.count == allIDs.count {

            _selectedApps.removeAll()

        } else {

            _selectedApps =
                Set(allIDs)
        }
    }

    // MARK: - Delete

    private func _bulkDeleteSelectedApps() {

        let appsToDelete =
            _selectedApps

        guard !appsToDelete.isEmpty else {
            return
        }

        withAnimation(
            .easeInOut(
                duration: 0.5
            )
        ) {

            for appUUID in appsToDelete {

                if let signedApp =
                    _signedApps.first(
                        where: {
                            $0.uuid == appUUID
                        }
                    )
                {

                    Storage.shared.deleteApp(
                        for: signedApp
                    )

                } else if let importedApp =
                    _importedApps.first(
                        where: {
                            $0.uuid == appUUID
                        }
                    )
                {

                    Storage.shared.deleteApp(
                        for: importedApp
                    )
                }
            }
        }

        DispatchQueue.main.async {

            _selectedApps.removeAll()
        }
    }
}
