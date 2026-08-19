//
//  HomeAppCardView.swift
//  Ksign
//
//  Created by KINDA on 19.08.2026.
//

import SwiftUI
import AltSourceKit

struct HomeAppCardView: View {
    let source: ASRepository
    let app: ASRepository.App

    var body: some View {
        HStack(spacing: 14) {
            appIcon

            VStack(alignment: .leading, spacing: 5) {
                Text(app.currentName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let description = app.currentDescription,
                   !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let version = app.currentVersion {
                        Label(
                            version,
                            systemImage: "number"
                        )
                    }

                    if let category = app.category,
                       !category.isEmpty {
                        Label(
                            category.capitalized,
                            systemImage: "square.grid.2x2"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                Color(
                    uiColor: .secondarySystemBackground
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .strokeBorder(
                Color.primary.opacity(0.06),
                lineWidth: 1
            )
        }
    }

    private var appIcon: some View {
        Group {
            if let iconURL = app.iconURL {
                AsyncImage(url: iconURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    iconPlaceholder
                }
            } else {
                iconPlaceholder
            }
        }
        .frame(
            width: 64,
            height: 64
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .strokeBorder(
                .black.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private var iconPlaceholder: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .fill(Color(uiColor: .tertiarySystemBackground))

            Image(systemName: "app.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
