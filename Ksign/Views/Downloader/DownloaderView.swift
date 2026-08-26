//
//  DownloaderView.swift
//  Ksign
//

import SwiftUI
import UniformTypeIdentifiers
import NimbleViews
import UIKit

struct DownloaderView: View {
    @StateObject private var downloadManager = IPADownloadManager()
    @StateObject private var libraryManager = DownloadManager.shared

    @State private var selectedItem: DownloadItem?
    @State private var webViewURL: URL?
    @State private var shareItems: [Any] = []
    @State private var showDocumentPicker = false
    @State private var fileToExport: URL?
    @State private var _searchText = ""

    private var filteredDownloadItems: [DownloadItem] {
        let items = downloadManager.finishedItems
        guard !_searchText.isEmpty else { return items }

        return items.filter {
            $0.title.localizedCaseInsensitiveContains(_searchText)
        }
    }

    var body: some View {
        NBNavigationView(.localized("Downloads")) {
            List {
                if !libraryManager.downloads.isEmpty ||
                    !downloadManager.activeItems.isEmpty {
                    NBSection(
                        .localized("Downloading"),
                        secondary: (
                            libraryManager.downloads.count +
                            downloadManager.activeItems.count
                        ).description
                    ) {
                        ForEach(libraryManager.downloads) { download in
                            AppStoreDownloadItemRow(download: download)
                        }

                        ForEach(downloadManager.activeItems) { item in
                            DownloadItemRow(
                                item: item,
                                shareItems: $shareItems,
                                importIpaToLibrary: importIpaToLibrary,
                                exportToFiles: exportToFiles,
                                deleteItem: deleteItem
                            )
                        }
                    }
                }

                NBSection(
                    .localized("Downloaded"),
                    secondary: filteredDownloadItems.count.description
                ) {
                    ForEach(filteredDownloadItems) { item in
                        DownloadItemRow(
                            item: item,
                            shareItems: $shareItems,
                            importIpaToLibrary: importIpaToLibrary,
                            exportToFiles: exportToFiles,
                            deleteItem: deleteItem
                        )
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if downloadManager.finishedItems.isEmpty &&
                    downloadManager.activeItems.isEmpty &&
                    libraryManager.downloads.isEmpty {

                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label(
                                .localized("No downloaded IPAs"),
                                systemImage: "square.and.arrow.down.fill"
                            )
                        } description: {
                            Text(
                                .localized(
                                    "Get started by downloading your first IPA file."
                                )
                            )
                        } actions: {
                            Button {
                                _addDownload()
                            } label: {
                                Text("Add Download").bg()
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $_searchText,
                placement: .platform()
            )
            .toolbar {
                NBToolbarButton(
                    "Add",
                    systemImage: "plus",
                    placement: .topBarTrailing
                ) {
                    _addDownload()
                }
            }
            .onAppear {
                downloadManager.loadDownloadedIPAs()
            }
            .onChange(of: libraryManager.downloads.count) { _ in
                downloadManager.loadDownloadedIPAs()
            }
            .onChange(of: downloadManager.activeItems.count) { _ in
                downloadManager.loadDownloadedIPAs()
            }
            .fullScreenCover(item: $webViewURL) { url in
                webViewSheet(url: url)
            }
            .sheet(isPresented: $showDocumentPicker) {
                documentPickerSheet
            }
        }
    }
}

private extension DownloaderView {
    @ViewBuilder
    var documentPickerSheet: some View {
        if let fileURL = fileToExport {
            FileExporterRepresentableView(
                urlsToExport: [fileURL],
                asCopy: true,
                useLastLocation: false,
                onCompletion: { _ in
                    showDocumentPicker = false
                }
            )
        }
    }

    func webViewSheet(url: URL) -> some View {
        WebViewSheet(
            downloadManager: downloadManager,
            url: url
        )
    }
}

private extension DownloaderView {
    func _addDownload() {
        UIAlertController.showAlertWithTextBox(
            title: .localized("Enter URL"),
            message: .localized(
                """
                Enter the URL of the website containing the IPA file
                (Direct install/ITMS Services) or URL to the IPA file, supported:
                - https://example.com
                - itms-services://?url=https://example.com
                - https://example.com/app.ipa
                """
            ),
            textFieldPlaceholder: .localized("https://example.com"),
            submit: .localized("OK"),
            cancel: .localized("Cancel"),
            onSubmit: { url in
                handleURLInput(url: url)
            }
        )
    }

    func handleURLInput(url: String) {
        let value = url.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !value.isEmpty else { return }

        // Preserve itms-services URLs instead of incorrectly converting them
        // into https.
        if value.lowercased().hasPrefix("itms-services://") {
            guard let serviceURL = URL(string: value) else {
                showError("Invalid URL format")
                return
            }

            downloadManager.handleITMSServicesURL(serviceURL) { result in
                switch result {
                case .success:
                    showSuccess("The IPA file is being downloaded!")
                case .failure(let error):
                    showError(error.localizedDescription)
                }
            }
            return
        }

        var finalURL = value

        if !finalURL.lowercased().hasPrefix("http://") &&
            !finalURL.lowercased().hasPrefix("https://") {
            finalURL = "https://" + finalURL
        }

        guard let validURL = URL(string: finalURL),
              let scheme = validURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            showError("Invalid URL format")
            return
        }

        if downloadManager.isIPAFile(validURL) {
            downloadManager.checkFileTypeAndDownload(url: validURL) { result in
                switch result {
                case .success:
                    showSuccess("The IPA file is being downloaded!")
                case .failure(let error):
                    showError(error.localizedDescription)
                }
            }
        } else {
            webViewURL = validURL
        }
    }

    func showError(_ message: String) {
        UIAlertController.showAlertWithOk(
            title: .localized("Error"),
            message: message
        )
    }

    func showSuccess(_ message: String) {
        UIAlertController.showAlertWithOk(
            title: .localized("Success"),
            message: message
        )
    }

    func shareItem(_ item: DownloadItem) {
        shareItems = [item.localPath]
        UIActivityViewController.show(
            activityItems: shareItems
        )
    }

    func importIpaToLibrary(_ file: DownloadItem) {
        let id = "KindaManualDownload_\(UUID().uuidString)"
        let download = libraryManager.startArchive(
            from: file.localPath,
            id: id
        )

        libraryManager.handlePachageFile(
            url: file.localPath,
            dl: download
        ) { error in
            DispatchQueue.main.async {
                if let error {
                    UIAlertController.showAlertWithOk(
                        title: .localized("Error"),
                        message: error.localizedDescription
                    )
                }

                if let index = libraryManager.getDownloadIndex(
                    by: download.id
                ) {
                    libraryManager.downloads.remove(at: index)
                }
            }
        }
    }

    func exportToFiles(_ item: DownloadItem) {
        fileToExport = item.localPath
        showDocumentPicker = true
    }

    func deleteItem(_ item: DownloadItem) {
        if !item.isFinished {
            downloadManager.cancelDownload(item)
            return
        }

        do {
            try FileManager.default.removeItem(
                at: item.localPath
            )

            withAnimation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.7
                )
            ) {
                if let index = downloadManager.downloadItems.firstIndex(
                    where: { $0.id == item.id }
                ) {
                    downloadManager.downloadItems.remove(
                        at: index
                    )
                }
            }
        } catch {
            showError(error.localizedDescription)
        }
    }
}
