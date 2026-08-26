//
// HomeAppActions.swift
// KINDA
//
// Add this file to the Ksign target.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData
import NimbleViews

/// Adds IPA import actions and a direct installation sheet to HomeView.
/// The existing HomeView remains responsible for the dashboard app list.
struct HomeAppActionsModifier: ViewModifier {
    @State private var showFileImporter = false
    @State private var showURLImporter = false
    @State private var ipaURL = ""
    @State private var selectedInstallApp: AnyApp?
    @State private var importTask: Task<Void, Never>?
    @State private var knownImportedUUIDs: Set<String> = []
    @State private var didInitializeImportedApps = false

    @FetchRequest(
        entity: Imported.entity(),
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \\Imported.date,
                ascending: false
            )
        ],
        animation: .snappy
    )
    private var importedApps: FetchedResults<Imported>

    private let downloadManager = DownloadManager.shared

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 10) {
                importBar
            }
            .sheet(isPresented: $showFileImporter) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.ipa, .tipa],
                    allowsMultipleSelection: true,
                    onDocumentsPicked: { urls in
                        importFiles(urls)
                    }
                )
            }
            .alert(
                "استيراد من الرابط",
                isPresented: $showURLImporter
            ) {
                TextField(
                    "رابط ملف IPA",
                    text: $ipaURL
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button("إلغاء", role: .cancel) {
                    ipaURL = ""
                }

                Button("استيراد") {
                    importURL()
                }
            } message: {
                Text("ضع رابط HTTPS مباشر لملف IPA.")
            }
            .sheet(item: $selectedInstallApp) { item in
                InstallPreviewView(
                    app: item.base
                )
                .presentationDetents([.height(230), .medium])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                knownImportedUUIDs = Set(
                    importedApps.compactMap { $0.uuid }
                )
                didInitializeImportedApps = true
            }
            .onChange(of: importedApps.count) { _ in
                guard didInitializeImportedApps else {
                    return
                }

                if let newApp = importedApps.first(where: {
                    guard let uuid = $0.uuid else {
                        return false
                    }
                    return !knownImportedUUIDs.contains(uuid)
                }) {
                    if let uuid = newApp.uuid {
                        knownImportedUUIDs.insert(uuid)
                    }
                    selectedInstallApp = AnyApp(
                        base: newApp
                    )
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .kindaShowInstall
                )
            ) { notification in
                guard
                    let app = notification.object
                        as? Imported
                else {
                    return
                }

                selectedInstallApp = AnyApp(
                    base: app
                )
            }
            .onDisappear {
                importTask?.cancel()
                importTask = nil
            }
    }

    private var importBar: some View {
        HStack(spacing: 10) {
            importButton(
                title: "من الملفات",
                subtitle: "IPA / TIPA",
                icon: "folder.fill"
            ) {
                showFileImporter = true
            }

            importButton(
                title: "من الرابط",
                subtitle: "رابط IPA",
                icon: "link"
            ) {
                showURLImporter = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.07),
                lineWidth: 0.7
            )
        }
        .padding(.horizontal, 12)
    }

    private func importButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .frame(
                        width: 34,
                        height: 34
                    )
                    .background(
                        Color.primary.opacity(0.08),
                        in: RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                    )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(title)
                        .font(
                            .system(
                                size: 12,
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
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(
                Color.primary.opacity(0.035),
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func importFiles(
        _ urls: [URL]
    ) {
        guard !urls.isEmpty else {
            return
        }

        for url in urls {
            let id =
                "KindaHomeImport_\(UUID().uuidString)"

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
                    DispatchQueue.main.async {
                        UIAlertController.showAlertWithOk(
                            title: "استيراد IPA",
                            message: error.localizedDescription
                        )
                    }
                }
            }
        }

        // The existing Core Data import pipeline emits the notification below.
        // We also refresh Home automatically through Core Data observation.
    }

    private func importURL() {
        let raw =
            ipaURL
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        ipaURL = ""

        guard
            let url = URL(string: raw),
            ["http", "https"].contains(
                url.scheme?.lowercased() ?? ""
            )
        else {
            UIAlertController.showAlertWithOk(
                title: "رابط غير صالح",
                message: "أدخل رابط HTTPS مباشر لملف IPA."
            )
            return
        }

        let id =
            "KindaHomeURL_\(UUID().uuidString)"

        _ = downloadManager.startDownload(
            from: url,
            id: id
        )
    }
}

extension View {
    /// Call this once at the end of HomeView's main view chain.
    func homeAppActions() -> some View {
        modifier(HomeAppActionsModifier())
    }
}

extension Notification.Name {
    static let kindaShowInstall =
        Notification.Name("kinda.showInstall")
}
