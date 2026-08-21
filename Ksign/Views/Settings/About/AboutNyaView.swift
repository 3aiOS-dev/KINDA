//
//  AboutNyaView.swift
//  Ksign
//
//  Created by Nagata Asami on 23/5/25.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct AboutNyaView: View {

    // MARK: Body
    var body: some View {
        NBList(.localized("About")) {

            Section {
                VStack(spacing: 8) {

                    Image(
                        uiImage: UIImage(
                            named: Bundle.main.iconFileName ?? ""
                        ) ?? UIImage()
                    )
                    .appIconStyle(size: 72)

                    Text("iQiraq")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.accent)

                    HStack(spacing: 4) {
                        Text("Version")
                        Text(Bundle.main.version)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(EmptyView())

            Section {
                HStack {
                    Text("iQiraq")
                    Spacer()
                    Text(Bundle.main.version)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Bundle ID")
                    Spacer()
                    Text(Bundle.main.bundleIdentifier ?? "")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
