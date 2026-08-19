//
//  HomeBannerView.swift
//  Ksign
//
//  Created by KINDA on 19.08.2026.
//

import SwiftUI
import AltSourceKit

struct HomeBannerView: View {
    let repository: ASRepository

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background

            LinearGradient(
                colors: [
                    .black.opacity(0.85),
                    .black.opacity(0.35),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(repository.name ?? "المتجر")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle = repository.subtitle,
                   !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                } else if let description = repository.description,
                          !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2.fill")

                    Text(
                        "\(repository.apps.count) تطبيق"
                    )
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
        }
        .frame(
            width: 330,
            height: 190
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .strokeBorder(
                .white.opacity(0.08),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.15),
            radius: 14,
            y: 8
        )
    }

    @ViewBuilder
    private var background: some View {
        if let headerURL = repository.headerURL {
            AsyncImage(url: headerURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    fallbackBackground

                case .empty:
                    ZStack {
                        fallbackBackground

                        ProgressView()
                            .tint(.white)
                    }

                @unknown default:
                    fallbackBackground
                }
            }
        } else {
            fallbackBackground
        }
    }

    private var fallbackBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    repository.tintColor ?? .accentColor,
                    .black.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let iconURL = repository.iconURL {
                AsyncImage(url: iconURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: 110,
                            height: 110
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 24,
                                style: .continuous
                            )
                        )
                        .opacity(0.28)
                } placeholder: {
                    EmptyView()
                }
            }
        }
    }
}
