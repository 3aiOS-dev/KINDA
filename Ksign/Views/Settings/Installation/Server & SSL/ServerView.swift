//
//  ServerView.swift
//  KINDA
//
//  Semi Local installation only.
//

import SwiftUI
import NimbleJSON
import NimbleViews

struct ServerView: View {
    @AppStorage("Feather.ipFix")
    private var _ipFix: Bool = true

    // The original project uses:
    // 0 = Fully Local
    // 1 = Semi Local
    @AppStorage("Feather.serverMethod")
    private var _serverMethod: Int = 1

    private let _serverMethods: [String] = [
        .localized("Semi Local")
    ]

    private let _serverPackUrl =
        "https://backloop.dev/pack.json"

    var body: some View {
        Group {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(
                            Color.primary.opacity(0.08),
                            in: RoundedRectangle(
                                cornerRadius: 10,
                                style: .continuous
                            )
                        )

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text("Installation Type")
                            .font(.system(size: 14, weight: .semibold))

                        Text("Semi Local")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }

                Toggle(
                    .localized("Only use localhost address"),
                    systemImage: "lifepreserver",
                    isOn: $_ipFix
                )
                .tint(.primary)
            }

            Section {
                Button(
                    .localized("Update SSL Certificates"),
                    systemImage: "arrow.down.doc"
                ) {
                    FR.downloadSSLCertificates(
                        from: _serverPackUrl
                    ) { success in
                        if !success {
                            DispatchQueue.main.async {
                                UIAlertController.showAlertWithOk(
                                    title: .localized(
                                        "SSL Certificates"
                                    ),
                                    message: .localized(
                                        "Failed to download, check your internet connection and try again."
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            _serverMethod = 1
            _ipFix = true
        }
    }
}
