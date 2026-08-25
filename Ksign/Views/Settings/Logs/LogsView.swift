//
//  LogsView.swift
//  KINDA
//
//  Improved signing logs.
//

import SwiftUI

struct LogsView: View {
    @ObservedObject var manager: LogsManager

    @Environment(\.dismiss)
    private var dismiss

    @State private var searchText = ""
    @State private var showOnlyErrors = false

    private var visibleEntries: [LogEntry] {
        manager.entries.filter { entry in
            let matchesSearch =
                searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(
                    searchText
                )

            // Keep this intentionally text based because LogEntry
            // in the project only guarantees message + id.
            let matchesErrors =
                !showOnlyErrors ||
                entry.message.localizedCaseInsensitiveContains("error") ||
                entry.message.localizedCaseInsensitiveContains("failed") ||
                entry.message.localizedCaseInsensitiveContains("fatal")

            return matchesSearch && matchesErrors
        }
    }

    private var lastID: LogEntry.ID? {
        visibleEntries.last?.id
    }

    var body: some View {
        ZStack {
            KindaTheme.pageBG
                .ignoresSafeArea()

            KindaGridBackground()

            VStack(spacing: 0) {
                header

                if visibleEntries.isEmpty {
                    emptyState
                } else {
                    logList
                }
            }
        }
        .navigationTitle("سجل التوقيع")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(
                displayMode: .automatic
            ),
            prompt: "البحث في السجل"
        )
        .toolbar {
            ToolbarItemGroup(
                placement: .topBarTrailing
            ) {
                Menu {
                    Button {
                        showOnlyErrors.toggle()
                    } label: {
                        Label(
                            showOnlyErrors
                                ? "عرض كل السجلات"
                                : "الأخطاء فقط",
                            systemImage:
                                showOnlyErrors
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "exclamationmark.triangle"
                        )
                    }

                    Button {
                        exportLogs()
                    } label: {
                        Label(
                            "تصدير السجل",
                            systemImage:
                                "square.and.arrow.up"
                        )
                    }
                    .disabled(manager.entries.isEmpty)

                    Button(role: .destructive) {
                        manager.clear()
                    } label: {
                        Label(
                            "مسح السجل",
                            systemImage: "trash"
                        )
                    }
                    .disabled(manager.entries.isEmpty)
                } label: {
                    Image(
                        systemName: "ellipsis.circle"
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            captureBar
        }
        .onAppear {
            scrollToLast()
        }
        .onChange(of: manager.entries.count) { _ in
            scrollToLast()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        manager.isCapturing
                            ? Color.green.opacity(0.13)
                            : Color.primary.opacity(0.08)
                    )

                Image(
                    systemName:
                        manager.isCapturing
                        ? "waveform"
                        : "terminal"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
            }
            .frame(width: 42, height: 42)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("سجل عملية التوقيع")
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )

                Text(
                    "\(manager.entries.count) سجل"
                )
                .font(
                    .system(
                        size: 11,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.secondary)
            }

            Spacer()

            if manager.isCapturing {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(
                            width: 7,
                            height: 7
                        )

                    Text("مباشر")
                        .font(
                            .system(
                                size: 10,
                                weight: .bold
                            )
                        )
                }
                .padding(
                    .horizontal,
                    9
                )
                .frame(height: 27)
                .background(
                    Color.green.opacity(0.10),
                    in: Capsule()
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 7
                ) {
                    ForEach(
                        visibleEntries
                    ) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .onAppear {
                scrollToLast(
                    proxy: proxy
                )
            }
            .onChange(
                of: manager.entries.count
            ) { _ in
                scrollToLast(
                    proxy: proxy
                )
            }
        }
    }

    private func logRow(
        _ entry: LogEntry
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 9
        ) {
            RoundedRectangle(
                cornerRadius: 2,
                style: .continuous
            )
            .fill(
                logAccent(
                    for: entry.message
                )
            )
            .frame(width: 3)

            Text(entry.message)
                .font(
                    .system(
                        size: 11,
                        weight: .regular,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            9
        )
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.055),
                lineWidth: 0.6
            )
        }
    }

    private func logAccent(
        for message: String
    ) -> Color {
        let lower = message.lowercased()

        if lower.contains("error") ||
            lower.contains("failed") ||
            lower.contains("fatal") {
            return .red
        }

        if lower.contains("warning") ||
            lower.contains("warn") {
            return .orange
        }

        if lower.contains("success") ||
            lower.contains("completed") ||
            lower.contains("complete") {
            return .green
        }

        return .secondary
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(
                    .system(
                        size: 30,
                        weight: .light
                    )
                )
                .foregroundStyle(.secondary)

            Text("لا توجد سجلات")
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )

            Text(
                "ستظهر خطوات التوقيع هنا بعد بدء العملية."
            )
            .font(
                .system(
                    size: 11,
                    weight: .regular
                )
            )
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.bottom, 50)
    }

    private var captureBar: some View {
        HStack(spacing: 10) {
            Button {
                if manager.isCapturing {
                    manager.stopCapture()
                } else {
                    manager.startCapture()
                }
            } label: {
                Image(
                    systemName:
                        manager.isCapturing
                        ? "pause.fill"
                        : "play.fill"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .bold
                    )
                )
                .frame(
                    width: 34,
                    height: 34
                )
                .background(
                    Color.primary.opacity(0.08),
                    in: Circle()
                )
            }
            .buttonStyle(.plain)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    manager.isCapturing
                        ? "التقاط السجل مفعل"
                        : "التقاط السجل متوقف"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )

                Text(
                    manager.isCapturing
                        ? "يتم عرض خطوات العملية مباشرة"
                        : "اضغط تشغيل لبدء الالتقاط"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .regular
                    )
                )
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            9
        )
        .background(
            .ultraThinMaterial,
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
                Color.primary.opacity(0.07),
                lineWidth: 0.7
            )
        }
        .padding(
            .horizontal,
            12
        )
        .padding(
            .bottom,
            7
        )
    }

    private func scrollToLast() {
        // The ScrollViewReader instance performs the actual scrolling.
    }

    private func scrollToLast(
        proxy: ScrollViewProxy
    ) {
        guard let id = lastID else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(
                    id,
                    anchor: .bottom
                )
            }
        }
    }

    private func exportLogs() {
        let logText =
            manager.exportToText()

        let dateFormatter =
            DateFormatter()

        dateFormatter.dateFormat =
            "yyyy-MM-dd-HHmmss"

        let timestamp =
            dateFormatter.string(
                from: Date()
            )

        let fileName =
            "Ksign-Logs-\(timestamp).txt"

        let tempDir =
            FileManager.default.temporaryDirectory

        let fileURL =
            tempDir.appendingPathComponent(
                fileName
            )

        do {
            try logText.write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )

            UIActivityViewController.show(
                activityItems: [fileURL]
            )
        } catch {
            print(
                "Error exporting logs: \(error.localizedDescription)"
            )
        }
    }
}
