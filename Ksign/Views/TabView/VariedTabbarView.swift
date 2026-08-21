import SwiftUI

extension Notification.Name {
    static let kindaOpenStoreApp = Notification.Name("KindaOpenStoreApp")
}

struct VariedTabbarView: View {
    @State private var selectedTab: TabEnum = .home
    @State private var isSearchPresented = false

    var body: some View {
        ZStack {
            TabEnum.view(for: selectedTab)
                .id(selectedTab)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .sheet(isPresented: $isSearchPresented) {
            AppSearchView { app in
                isSearchPresented = false

                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .home
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NotificationCenter.default.post(
                        name: .kindaOpenStoreApp,
                        object: nil,
                        userInfo: ["appID": app.id]
                    )
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(TabEnum.defaultTabs, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding(5)
            .frame(height: 56)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        Color.primary.opacity(0.10),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: .black.opacity(0.10),
                radius: 16,
                y: 5
            )
            .frame(maxWidth: 250)

            Button {
                isSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(
                        .system(
                            size: 19,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color.black, in: Circle())
                    .shadow(
                        color: .black.opacity(0.22),
                        radius: 12,
                        y: 5
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(.localized("البحث"))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func tabButton(_ tab: TabEnum) -> some View {
        Button {
            guard selectedTab != tab else { return }

            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(
                        .system(
                            size: 18,
                            weight: selectedTab == tab ? .bold : .medium
                        )
                    )

                Text(tab.title)
                    .font(
                        .system(
                            size: 9,
                            weight: selectedTab == tab ? .semibold : .medium
                        )
                    )
                    .lineLimit(1)
            }
            .foregroundStyle(
                selectedTab == tab ? .primary : .secondary
            )
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background {
                if selectedTab == tab {
                    Capsule()
                        .fill(Color.primary.opacity(0.09))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - البحث المنفصل

private struct AppSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var storeManager = KindaStoreManager.shared
    @State private var searchText = ""

    let onSelect: (StoreApp) -> Void

    private var results: [StoreApp] {
        storeManager.filtered(searchText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if storeManager.isLoading && storeManager.apps.isEmpty {
                    ProgressView()
                } else if results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(
                            searchText.isEmpty
                            ? "لا توجد تطبيقات"
                            : "لا توجد نتائج"
                        )
                        .font(.system(size: 16, weight: .semibold))

                        Text(
                            searchText.isEmpty
                            ? "ستظهر هنا التطبيقات الموجودة في الرئيسية."
                            : "جرّب البحث باسم التطبيق أو Bundle ID."
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(30)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(results) { app in
                                Button {
                                    onSelect(app)
                                } label: {
                                    HStack(spacing: 12) {
                                        StoreIconView(
                                            urlString: app.iconURL,
                                            size: 46
                                        )

                                        VStack(
                                            alignment: .trailing,
                                            spacing: 3
                                        ) {
                                            Text(app.name)
                                                .font(
                                                    .system(
                                                        size: 15,
                                                        weight: .semibold
                                                    )
                                                )
                                                .foregroundStyle(.primary)
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .trailing
                                                )

                                            Text(app.bundleId)
                                                .font(
                                                    .system(
                                                        size: 10,
                                                        design: .monospaced
                                                    )
                                                )
                                                .foregroundStyle(.secondary)
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .trailing
                                                )
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(
                                            cornerRadius: 16,
                                            style: .continuous
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await storeManager.load()
                    }
                }
            }
            .navigationTitle(.localized("البحث"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: .localized("ابحث عن تطبيق")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(.localized("إغلاق")) {
                        dismiss()
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            if storeManager.apps.isEmpty {
                await storeManager.load()
            }
        }
    }
}
