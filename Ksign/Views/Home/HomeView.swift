//
//  HomeView.swift
//  Ksign
//
//  Created for KINDA
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
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
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(importedApps)
        }

        return importedApps.filter {
            ($0.value(forKey: "name") as? String)?
                .localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var filteredSignedApps: [Signed] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        NBNavigationView("الرئيسية") {

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
                prompt: "البحث عن تطبيق"
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
                                    "تحديد الكل",
                                    systemImage: "checklist"
                                )
                            }

                            Button(role: .destructive) {
                                deleteSelectedApps()
                            } label: {
                                Label(
                                    "حذف المحدد",
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

            // MARK: Sheets

            .sheet(item: $selectedInfoAppPresenting) { app in
                LibraryInfoView(app: app.base)
            }

            .sheet(item: $selectedInstallAppPresenting) { app in
                InstallPreviewView(
                    app: app.base,
                    isSharing: app.archive
                )
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
            }

            .fullScreenCover(item: $selectedSigningAppPresenting) { app in
                SigningView(
                    app: app.base,
                    signAndInstall: app.signAndInstall
                )
                .compatNavigationTransition(
                    id: app.base.uuid ?? "",
                    ns: namespace
                )
            }

            .fullScreenCover(item: $selectedDylibsAppPresenting) { app in
                DylibsView(app: app.base)
                    .compatNavigationTransition(
                        id: app.base.uuid ?? "",
                        ns: namespace
                    )
            }

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

            // MARK: Import

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

            // MARK: URL Download

            .alert(
                "استيراد من رابط",
                isPresented: $isDownloading
            ) {

                TextField(
                    "رابط IPA",
                    text: $downloadURL
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button("إلغاء", role: .cancel) {
                    downloadURL = ""
                }

                Button("استيراد") {

                    importFromURL()

                }
            }

            // MARK: Install Notification

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

                Text("مرحباً بك")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("تطبيقاتك في مكان واحد")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                Text(
                    "\(allAppsCount) تطبيق"
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
                title: "استيراد",
                icon: "square.and.arrow.down",
                action: {
                    isImporting = true
                }
            )

            quickAction(
                title: "من رابط",
                icon: "link",
                action: {
                    isDownloading = true
                }
            )

            quickAction(
                title: "المكتبة",
                icon: "square.grid.2x2",
                action: {
                    // سيتم ربطها لاحقاً عند تطوير التنقل
                }
            )
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
                    .font(.system(size: 20, weight: .semibold))

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 18)
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

                Text("التطبيقات")
                    .font(.title2.bold())

                Spacer()

                Text(
                    "\(allAppsCount)"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if filteredImportedApps.isEmpty &&
                filteredSignedApps.isEmpty {

                emptyAppsView

            } else {

                LazyVStack(
                    spacing: 10
                ) {

                    ForEach(
                        filteredImportedApps,
                        id: \.uuid
                    ) { app in

                        appRow(
                            app: app
                        )
                    }

                    ForEach(
                        filteredSignedApps,
                        id: \.uuid
                    ) { app in

                        appRow(
                            app: app
                        )
                    }
                }
            }
        }
    }

    // MARK: - Application Row

    private func appRow<T: NSManagedObject & AppInfoPresentable>(
        app: T
    ) -> some View {

        LibraryCellView(
            app: app,
            selectedInfoAppPresenting: $selectedInfoAppPresenting,
            selectedSigningAppPresenting: $selectedSigningAppPresenting,
            selectedInstallAppPresenting: $selectedInstallAppPresenting,
            selectedAppDylibsPresenting: $selectedDylibsAppPresenting,
            selectedApps: $selectedApps
        )
        .compatMatchedTransitionSource(
            id: app.uuid ?? "",
            ns: namespace
        )
    }

    // MARK: - Empty State

    private var emptyAppsView: some View {

        VStack(spacing: 14) {

            Image(systemName: "square.grid.2x2")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("لا توجد تطبيقات")
                .font(.headline)

            Text(
                "ابدأ باستيراد ملف IPA لإضافته إلى الرئيسية."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                isImporting = true
            } label: {

                Label(
                    "استيراد تطبيق",
                    systemImage: "plus"
                )
                .bg()
            }
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 35)
    }

    // MARK: - Import Menu

    @ViewBuilder
    private var importActions: some View {

        Button {
            isImporting = true
        } label: {

            Label(
                "استيراد من الملفات",
                systemImage: "folder"
            )
        }

        Button {
            isDownloading = true
        } label: {

            Label(
                "استيراد من رابط",
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

                DispatchQueue.main.async {

                    if error != nil {

                        UIAlertController.showAlertWithOk(
                            title: .localized("Error"),
                            message: .localized(
                                "حدث خطأ أثناء استيراد التطبيق."
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
            downloadURL
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard
            !value.isEmpty,
            let url = URL(string: value)
        else {

            UIAlertController.showAlertWithOk(
                title: .localized("Error"),
                message: .localized(
                    "الرابط غير صالح."
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

        let appsToDelete =
            selectedApps

        withAnimation(
            .easeInOut(duration: 0.3)
        ) {

            for id in appsToDelete {

                if let signedApp =
                    signedApps.first(
                        where: { $0.uuid == id }
                    ) {

                    Storage.shared.deleteApp(
                        for: signedApp
                    )

                } else if let importedApp =
                    importedApps.first(
                        where: { $0.uuid == id }
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
