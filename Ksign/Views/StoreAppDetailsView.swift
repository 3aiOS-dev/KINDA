//
// StoreAppDetailsView.swift
// KINDA
//
// Details-only screen for dashboard applications.
//

import SwiftUI

struct StoreAppDetailsView: View {
    let app: StoreApp
    let install: () -> Void
    let isLoading: Bool

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                KindaTheme.pageBG
                    .ignoresSafeArea()

                KindaGridBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        StoreIconView(
                            urlString: app.iconURL,
                            size: 92
                        )

                        VStack(spacing: 5) {
                            Text(app.name)
                                .font(
                                    .system(
                                        size: 22,
                                        weight: .bold
                                    )
                                )
                                .multilineTextAlignment(.center)

                            Text(
                                app.bundleId.isEmpty
                                    ? "Bundle ID غير متوفر"
                                    : app.bundleId
                            )
                            .font(
                                .system(
                                    size: 10,
                                    weight: .medium,
                                    design: .monospaced
                                )
                            )
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 8) {
                            detailBox(
                                "الإصدار",
                                app.version
                            )

                            detailBox(
                                "الحجم",
                                app.sizeText ?? "—"
                            )

                            detailBox(
                                "الفئة",
                                app.category
                            )
                        }

                        if !app.appDescription
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty {
                            VStack(
                                alignment: .trailing,
                                spacing: 8
                            ) {
                                Text("التفاصيل")
                                    .font(
                                        .system(
                                            size: 14,
                                            weight: .bold
                                        )
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .trailing
                                    )

                                Text(app.appDescription)
                                    .font(
                                        .system(
                                            size: 12,
                                            weight: .regular
                                        )
                                    )
                                    .foregroundStyle(.secondary)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .trailing
                                    )
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(14)
                            .background(
                                .ultraThinMaterial,
                                in: RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                            )
                        }

                        Button {
                            install()
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }

                                Text(
                                    isLoading
                                        ? "جاري التثبيت..."
                                        : "تثبيت"
                                )
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .bold
                                    )
                                )
                            }
                            .foregroundStyle(.primary)
                            .frame(
                                maxWidth: .infinity
                            )
                            .frame(height: 48)
                            .background(
                                .ultraThinMaterial,
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("تفاصيل التطبيق")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("إغلاق") {
                        dismiss()
                    }
                }
            }
        }
        .environment(
            \.layoutDirection,
            .rightToLeft
        )
    }

    private func detailBox(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(
                    .system(
                        size: 9,
                        weight: .medium
                    )
                )
                .foregroundStyle(.secondary)

            Text(
                value.isEmpty ? "—" : value
            )
            .font(
                .system(
                    size: 11,
                    weight: .bold
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(
            maxWidth: .infinity
        )
        .frame(height: 48)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }
}
