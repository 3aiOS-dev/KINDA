//
//  HomeView.swift
//  Ksign
//
//  Created for KINDA
//

import SwiftUI
import CoreData
import NimbleViews

struct HomeView: View {

    // MARK: - Managers

    @StateObject private var downloadManager = DownloadManager.shared

    // MARK: - State

    @State private var searchText = ""
    @State private var selectedApps: Set<String> = []
    @State private var editMode: EditMode = .inactive

    @State private var isImporting = false
    @State private var isDownloading = false
    @State private var downloadURL = ""

    @State private var selectedInfoAppPresenting: AnyApp?
    @State private var selectedSigningAppPresenting: AnyApp?
    @State private var selectedInstallAppPresenting: AnyApp?
    @State private var selectedDylibsAppPresenting: AnyApp?

    @State private var isBulkSigningPresenting = false
    @State private var isBulkInstallingPresenting = false

    @Namespace private var namespace

    // MARK: - Core Data

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

    // MARK: - Filtered Apps

    private var filteredImportedApps: [Imported] {
        if searchText.isEmpty {
            return Array(importedApps)
        }

        return importedApps.filter {
            ($0.value(forKey: "name") as? String)?
                .localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var filteredSignedApps: [Signed] {
        if searchText.isEmpty {
            return Array(signedApps)
        }

        return signedApps.filter {
            ($0.value(forKey: "name") as? String)?
                .localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var allAppsCount: Int {
        importedApps.count + signedApps.count
    }

    // MARK: - Body

    var body: some View {
        NBNavigationView(.localized("Home")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: Banner

                    homeBanner

                    // MARK: Quick Actions

                    quickActions

                    // MARK: Applications

                    applicationsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .searchable(
                text: $searchText,
                placement: .platform(),
                prompt: .localized("Search")
            )
            .toolbar {

                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .topBarTrailing) {

                    if editMode.isEditing {

                        Menu {

                            Button {
                                selectAllApps()
                            } label: {
                                Label(
                                    .localized("Select All"),
                                    systemImage: "checklist"
                                )
                            }

                            Button(
                                role: .destructive
                            ) {
                                deleteSelectedApps()
                            } label: {
                                Label(
                                    .localized("Delete"),
                                    systemImage: "trash"
                                )
                            }
                            .disabled(selectedApps.isEmpty)

                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }

                    } else {

                        Menu {
                            importActions
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)

            // MARK: App Info

            .sheet(item: $selectedInfoAppPresenting) { app in
                LibraryInfoView(app: app.base)
            }

            // MARK: Install

            .sheet(item: $selectedInstallAppPresenting) { app in
                InstallPreviewView(
                    app: app.base,
                    isSharing: app.archive
                )
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
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
                item: $selectedDylibsAppPresenting
            ) { app in
                DylibsView(app: app.base)
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
                        (importedApps.first {
                            $0.uuid == id
                        } as AppInfoPresentable?)
                        ??
                        (signedApps.first {
                            $0.uuid == id
                        } as AppInfoPresentable?)
                    }
                )
                .compatNavigationTransition(
                    id: selectedApps.joined(separator: ","),
                    ns: namespace
                )
            }

            // MARK: Bulk Install

            .sheet(
                isPresented: $isBulkInstallingPresenting
            ) {
                BulkInstallPreviewView(
                    apps: selectedApps.compactMap { id in
                        (importedApps.first {
                            $0.uuid == id
                        } as AppInfoPresentable?)
                        ??
                        (signedApps.first {
                            $0.uuid == id
                        } as AppInfoPresentable?)
                    }
                )
                .presentationDetents([
                    .medium,
                    .large
                ])
                .presentationDragIndicator(.visible)
            }

            // MARK: File Import

            .sheet(isPresented: $isImporting) {

                FileImporterRepresentableView(
                    allowedContentTypes: [
                        .ipa,
                        .tipa
                    ],
                    allowsMultipleSelection: true
                ) { urls in

                    importIPAFiles(urls)
                }
            }

            // MARK: URL Import

            .alert(
                .localized("Import from URL"),
                isPresented: $isDownloading
            ) {

                TextField(
                    .localized("URL"),
                    text: $downloadURL
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button(
                    .localized("Cancel"),
                    role: .cancel
                ) {
                    downloadURL = ""
                }

                Button(.localized("OK")) {
                    importFromURL()
                }
            }

            // MARK: Installation Notification

            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("feather.installApp")
                )
            ) { _ in

                if let app = signedApps.first {
                    selectedInstallAppPresenting = AnyApp(
                        base: app
                    )
                }
            }

            // MARK: Edit Mode

            .onChange(of: editMode) { state in

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

    // MARK: - Banner

    private var homeBanner: some View {

        ZStack(alignment: .bottomLeading) {

            RoundedRectangle(cornerRadius: 24)
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
                .frame(height: 190)

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)

                Text(.localized("Welcome"))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text(.localized("Your Apps In One Place"))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                Text(
                    "\(allAppsCount) " +
                    .localized("Apps")
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(22)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 24)
        )
        .shadow(
            color: .black.opacity(0.08),
            radius: 12,
            y: 5
        )
    }

    // MARK: - Quick Actions

    private var quickActions: some View {

        HStack(spacing: 12) {

            quickAction(
                title: .localized("Import"),
                icon: "square.and.arrow.down"
            ) {
                isImporting = true
            }

            quickAction(
                title: .localized("From URL"),
                icon: "link"
            ) {
                isDownloading = true
            }

            quickAction(
                title: .localized("Library"),
                icon: "square.grid.2x2"
            ) {
                NotificationCenter.default.post(
                    name: NSNotification.Name(
                        "kinda.openLibrary"
                    ),
                    object: nil
                )
            }
        }
    }

    private func quickAction(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            VStack(spacing: 8) {

                Image(systemName: icon)
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
            .frame(maxWidth: .infinity)
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

    private var applicationsSection: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Text(.localized("Applications"))
                    .font(.title2.bold())

                Spacer()

                Text("\(allAppsCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if filteredImportedApps.isEmpty &&
                filteredSignedApps.isEmpty {

                emptyAppsView

            } else {

                LazyVStack(spacing: 10) {

                    ForEach(
                        filteredImportedApps,
                        id: \.uuid
                    ) { app in

                        applicationRow(
                            app
                        )
                    }

                    ForEach(
                        filteredSignedApps,
                        id: \.uuid
                    ) { app in

                        applicationRow(
                            app
                        )
                    }
                }
            }
        }
    }

    // MARK: - Application Row

    private func applicationRow(
        _ app: AppInfoPresentable
    ) -> some View {

        LibraryCellView(
            app: app,
            selectedInfoAppPresenting:
                $selectedInfoAppPresenting,
            selectedSigningAppPresenting:
                $selectedSigningAppPresenting,
            selectedInstallAppPresenting:
                $selectedInstallAppPresenting,
            selectedAppDylibsPresenting:
                $selectedDylibsAppPresenting,
            selectedApps:
                $selectedApps
        )
        .compatMatchedTransitionSource(
            id: app.uuid ?? "",
            ns: namespace
        )
    }

    // MARK: - Empty State

    private var emptyAppsView: some View {

        VStack(spacing: 14) {

            Image(
                systemName:
                    "square.grid.2x2"
            )
            .font(.system(size: 42))
            .foregroundStyle(.secondary)

            Text(.localized("No Apps"))
                .font(.headline)

            Text(
                .localized(
                    "Get started by importing your first IPA file."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                isImporting = true
            } label: {

                Label(
                    .localized("Import"),
                    systemImage: "plus"
                )
                .bg()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
    }

    // MARK: - Import Menu

    @ViewBuilder
    private var importActions: some View {

        Button {
            isImporting = true
        } label: {

            Label(
                .localized("Import from Files"),
                systemImage: "folder"
            )
        }

        Button {
            isDownloading = true
        } label: {

            Label(
                .localized("Import from URL"),
                systemImage: "globe"
            )
        }
    }

    // MARK: - Import IPA

    private func importIPAFiles(
        _ urls: [URL]
    ) {

        guard !urls.isEmpty else {
            return
        }

        for url in urls {

            let id =
                "KindaManualImport_\(UUID().uuidString)"

            let download =
                downloadManager.startArchive(
                    from: url,
                    id: id
                )

            downloadManager.handlePachageFile(
                url: url,
                dl: download
            ) { error in

                if error != nil {

                    DispatchQueue.main.async {

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
    }

    // MARK: - URL Import

    private func importFromURL() {

        let value =
            downloadURL.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !value.isEmpty,
            let url = URL(string: value)
        else {

            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized(
                    "The URL is invalid."
                )
            )

            return
        }

        let id =
            "KindaURLImport_\(UUID().uuidString)"

        _ = downloadManager.startDownload(
            from: url,
            id: id
        )

        downloadURL = ""
    }

    // MARK: - Selection

    private func selectAllApps() {

        let allIDs =
            importedApps.compactMap(\.uuid)
            +
            signedApps.compactMap(\.uuid)

        if selectedApps.count == allIDs.count {

            selectedApps.removeAll()

        } else {

            selectedApps = Set(allIDs)
        }
    }

    // MARK: - Delete

    private func deleteSelectedApps() {

        guard !selectedApps.isEmpty else {
            return
        }

        let appsToDelete = selectedApps

        withAnimation(
            .easeInOut(duration: 0.3)
        ) {

            for id in appsToDelete {

                if let signedApp =
                    signedApps.first(
                        where: {
                            $0.uuid == id
                        }
                    ) {

                    Storage.shared.deleteApp(
                        for: signedApp
                    )

                } else if let importedApp =
                    importedApps.first(
                        where: {
                            $0.uuid == id
                        }
                    ) {

                    Storage.shared.deleteApp(
                        for: importedApp
                    )
                }
            }
        }

        selectedApps.removeAll()
        editMode = .inactive
    }
}
