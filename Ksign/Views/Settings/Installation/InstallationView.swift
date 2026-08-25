//
//  InstallationView.swift
//  KINDA
//
//  Installation is intentionally limited to Semi Local.
//

import SwiftUI
import NimbleViews

struct InstallationView: View {
    // 1 = Semi Local in the original project.
    @AppStorage("Feather.serverMethod")
    private var _serverMethod: Int = 1

    var body: some View {
        ZStack {
            KindaTheme.pageBG
                .ignoresSafeArea()

            KindaGridBackground()

            NBList(.localized("Installation")) {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 18, weight: .semibold))
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
                            Text("نوع التثبيت")
                                .font(.system(size: 15, weight: .semibold))

                            Text("محلي جزئياً")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                } footer: {
                    Text(
                        "يستخدم التثبيت المحلي جزئياً لتثبيت التطبيقات من خلال الخادم المحلي مع إبقاء المسار متوافقاً مع نظام التثبيت الحالي."
                    )
                }

                ServerView()
            }
            .scrollContentBackground(.hidden)
        }
        .onAppear {
            // Force Semi Local every time the page opens.
            _serverMethod = 1
        }
    }
}
