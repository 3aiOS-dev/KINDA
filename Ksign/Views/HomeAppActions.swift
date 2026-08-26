//
// HomeAppActions.swift
// KINDA
//
// مساعد بسيط لتوجيه ملفات IPA إلى شاشة التثبيت الحالية.
// لا ينشئ شاشة تفاصيل ولا تبويب توقيع.
//

import Foundation
import SwiftUI

enum HomeAppActions {
    static func openInstaller(
        with url: URL
    ) {
        NotificationCenter.default.post(
            name: .kindaOpenInstallPreview,
            object: nil,
            userInfo: [
                "url": url
            ]
        )
    }
}
