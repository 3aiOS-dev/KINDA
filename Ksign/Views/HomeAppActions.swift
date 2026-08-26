//
// HomeAppActions.swift
// KINDA
//
// لا توجد صفحة تفاصيل ولا تبويب توقيع.
// هذا الملف اختياري ويمكن حذفه إذا لم يكن مستخدماً في المشروع.
//

import Foundation

enum HomeAppActions {
    static func openInstaller(
        with url: URL
    ) {
        NotificationCenter.default.post(
            name:
                NSNotification.Name(
                    "kinda.directInstallURL"
                ),
            object: nil,
            userInfo: [
                "url": url
            ]
        )
    }
}
