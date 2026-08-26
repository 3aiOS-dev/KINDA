//
// HomeView.swift
// KINDA
//
// التطبيقات من لوحة التحكم فقط.
// زر تثبيت ينزّل IPA فعلياً ثم يمرره إلى DownloadManager
// الموجود في المشروع لمعالجة/استيراد الحزمة.
//

import SwiftUI
import CoreData
import NimbleViews
import UniformTypeIdentifiers
import UIKit

@MainActor
struct HomeView: View {
    @StateObject private var store = KindaStoreManager.shared
    @StateObject private var ipaDownloader = IPADownloadManager()
    @StateObject private var library = DownloadManager.shared

    @State private var searchText = ""
    @State private var selectedCategory = "الكل"
    @State private var importingFile = false
    @State private var showingURL = false
    @State private var ipaURL = ""
    @State private var installingID: String?
    @State private var progress: [String: Double] = [:]
    @State private var errorMessage: String?

    @FetchRequest(
        entity: Imported.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Imported.date, ascending: false)
        ],
        animation: .snappy
    )
    private var imported: FetchedResults<Imported>

    private var filtered: [StoreApp] {
        store.apps.filter { app in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let textMatch = query.isEmpty
                || app.name.localizedCaseInsensitiveContains(query)
                || app.bundleIdentifier.localizedCaseInsensitiveContains(query)

            let categoryMatch = selectedCategory == "الكل"
                || app.category == selectedCategory

            return textMatch && categoryMatch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 11) {
                    header
                    search
                    categoryBar

                    if store.isLoading && store.apps.isEmpty {
                        ProgressView("جاري تحميل التطبيقات...")
                            .padding(.vertical, 35)
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { app in
                            appRow(app)
                        }

                        if store.hasMorePages {
                            Button {
                                Task { await store.loadNextPage() }
                            } label: {
                                HStack {
                                    if store.isLoading { ProgressView().controlSize(.small) }
                                    Text(store.isLoading ? "جاري التحميل..." : "التالي")
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .refreshable { await store.reload() }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            if store.apps.isEmpty {
                await store.reload()
            }
        }
        .fileImporter(
            isPresented: $importingFile,
            allowedContentTypes: [.ipa, .tipa],
            allowsMultipleSelection: false
        ) { result in
            importFile(result)
        }
        .sheet(isPresented: $showingURL) {
            urlSheet
        }
        .alert("خطأ", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("حسناً", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("الرئيسية")
                .font(.system(size: 22, weight: .bold))

            Text("تطبيقات لوحة التحكم")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("ألعاب وتطبيقات والمزيد", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                category("الكل")

                ForEach(store.categories, id: \.self) { category in
                    categoryChip(category)
                }
            }
        }
    }

    private func category(_ title: String) -> some View {
        categoryChip(title)
    }

    private func categoryChip(_ title: String) -> some View {
        Button {
            selectedCategory = title
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selectedCategory == title ? .primary : .secondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    selectedCategory == title
                        ? Color.primary.opacity(0.12)
                        : Color.secondary.opacity(0.07),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func appRow(_ app: StoreApp) -> some View {
        HStack(spacing: 11) {
            DashboardIconView(urlString: app.iconURL)

            VStack(alignment: .trailing, spacing: 4) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 7) {
                    if !app.version.isEmpty {
                        Text("v\(app.version)")
                    }
                    if !app.category.isEmpty {
                        Text(app.category)
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                startInstall(app)
            } label: {
                if installingID == app.id {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.small)
                        Text("\(Int((progress[app.id] ?? 0) * 100))%")
                    }
                } else {
                    Text("تثبيت")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(installingID != nil)
        }
        .padding(11)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)

            Text(store.lastError ?? "لا توجد تطبيقات")
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)

            Button("إعادة المحاولة") {
                Task { await store.reload() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 45)
    }

    private func startInstall(_ app: StoreApp) {
        guard installingID == nil else { return }

        let value = app.ipaURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            errorMessage = "رابط IPA للتطبيق غير صالح."
            return
        }

        installingID = app.id
        progress[app.id] = 0

        let downloadID = ipaDownloader.startDownload(
            url: url,
            filename: app.name + ".ipa"
        )

        Task {
            await waitForIPA(
                id: downloadID,
                app: app
            )
        }
    }

    private func waitForIPA(id: UUID, app: StoreApp) async {
        for _ in 0..<1800 {
            if let item = ipaDownloader.downloadItems.first(where: { $0.id == id }) {
                progress[app.id] = item.progress

                if item.isFinished {
                    importDownloadedIPA(item, app: app)
                    return
                }
            } else {
                break
            }

            try? await Task.sleep(for: .milliseconds(200))
        }

        if installingID == app.id {
            installingID = nil
            progress[app.id] = nil
            errorMessage = "انتهى وقت تنزيل IPA أو فشل التنزيل."
        }
    }

    private func importDownloadedIPA(_ item: DownloadItem, app: StoreApp) {
        let id = "KindaDashboard_\(UUID().uuidString)"
        let archive = library.startArchive(from: item.localPath, id: id)

        library.handlePachageFile(url: item.localPath, dl: archive) { error in
            Task { @MainActor in
                if let error {
                    installingID = nil
                    progress[app.id] = nil
                    errorMessage = "تعذر معالجة IPA: \(error.localizedDescription)"
                    return
                }

                installingID = nil
                progress[app.id] = nil

                // إعادة تحميل FetchedResults حتى يظهر التطبيق المستورد.
                // لا نعتمد على ترتيب العناصر لأن Core Data قد يعيد ترتيبها.
                _ = imported.first
            }
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription

        case .success(let urls):
            guard let url = urls.first else { return }

            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let id = "KindaManual_\(UUID().uuidString)"
            let archive = library.startArchive(from: url, id: id)

            library.handlePachageFile(url: url, dl: archive) { error in
                if let error {
                    Task { @MainActor in
                        errorMessage = "تعذر استيراد IPA: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private var urlSheet: some View {
        NavigationStack {
            Form {
                Section("رابط IPA") {
                    TextField("https://example.com/app.ipa", text: $ipaURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Button("تنزيل واستيراد") {
                    let value = ipaURL.trimmingCharacters(in: .whitespacesAndNewlines)

                    guard let url = URL(string: value),
                          let scheme = url.scheme?.lowercased(),
                          scheme == "http" || scheme == "https" else {
                        errorMessage = "الرابط غير صالح."
                        return
                    }

                    showingURL = false

                    let id = "KindaURL_\(UUID().uuidString)"
                    let downloadID = ipaDownloader.startDownload(
                        url: url,
                        filename: url.lastPathComponent.isEmpty ? "app.ipa" : url.lastPathComponent
                    )

                    Task {
                        await waitForManualURLDownload(id: downloadID, archiveID: id)
                    }
                }
            }
            .navigationTitle("استيراد IPA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إلغاء") { showingURL = false }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func waitForManualURLDownload(id: UUID, archiveID: String) async {
        for _ in 0..<1800 {
            if let item = ipaDownloader.downloadItems.first(where: { $0.id == id }) {
                if item.isFinished {
                    let archive = library.startArchive(from: item.localPath, id: archiveID)

                    library.handlePachageFile(url: item.localPath, dl: archive) { error in
                        if let error {
                            Task { @MainActor in
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    return
                }
            } else {
                return
            }

            try? await Task.sleep(for: .milliseconds(200))
        }

        errorMessage = "انتهى وقت التنزيل."
    }
}
