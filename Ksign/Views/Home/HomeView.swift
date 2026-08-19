//
//  HomeView.swift
//  Ksign
//
//  Created by KINDA on 19.08.2026.
//

import SwiftUI
import CoreData
import AltSourceKit

struct HomeView: View {
    @StateObject private var viewModel = SourcesViewModel.shared

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \AltSource.name,
                ascending: true
            )
        ],
        animation: .snappy
    )
    private var sources: FetchedResults<AltSource>

    private var repositories: [ASRepository] {
        viewModel.sources.values.sorted {
            ($0.name ?? "").localizedCaseInsensitiveCompare(
                $1.name ?? ""
            ) == .orderedAscending
        }
    }

    private var applications: [HomeAppItem] {
        repositories
            .flatMap { repository in
                repository.apps.prefix(12).map {
                    HomeAppItem(
                        source: repository,
                        app: $0
                    )
                }
            }
    }

    private var banners: [ASRepository] {
        repositories.filter {
            $0.headerURL != nil ||
            $0.iconURL != nil ||
            !$0.apps.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !banners.isEmpty {
                        bannerSection
                    }

                    if !applications.isEmpty {
                        applicationsSection
                    } else if viewModel.isFinished {
                        emptyState
                    } else {
                        loadingState
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("الرئيسية")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.fetchSources(
                    sources,
                    refresh: true
                )
            }
            .task(id: sources.map(\.objectID)) {
                await viewModel.fetchSources(sources)
            }
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مميز")
                .font(.title2.weight(.bold))
                .padding(.horizontal)

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                LazyHStack(spacing: 14) {
                    ForEach(
                        Array(banners.prefix(5)),
                        id: \.self
                    ) { repository in
                        HomeBannerView(
                            repository: repository
                        )
                    }
                }
                .padding(.horizontal)
            }
            .scrollTargetLayout()
        }
    }

    // MARK: - Applications

    private var applicationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("التطبيقات")
                    .font(.title2.weight(.bold))

                Spacer()

                Text("\(applications.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 10) {
                ForEach(applications) { item in
                    NavigationLink {
                        SourceAppsDetailView(
                            source: item.source,
                            app: item.app
                        )
                    } label: {
                        HomeAppCardView(
                            source: item.source,
                            app: item.app
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("جاري تحميل التطبيقات…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Empty

    private var emptyState: some View {
        ContentUnavailableView(
            "لا توجد تطبيقات",
            systemImage: "square.grid.2x2",
            description: Text(
                "أضف مصدرًا من قسم المصادر لعرض التطبيقات هنا."
            )
        )
        .padding(.vertical, 50)
    }
}

// MARK: - Home App Item

private struct HomeAppItem: Identifiable {
    let source: ASRepository
    let app: ASRepository.App

    var id: String {
        "\(source.id ?? UUID().uuidString)-\(app.currentUniqueId)"
    }
}
