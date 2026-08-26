//
// HomeInstallPreviewBridge.swift
// KINDA
//
// يربط زر تثبيت الرئيسية مع شاشة InstallPreview الموجودة بالمشروع.
// لا يوجد تبويب توقيع.
//

import SwiftUI
import UIKit

@MainActor
final class HomeInstallPreviewBridge: ObservableObject {
    static let shared = HomeInstallPreviewBridge()

    private init() {}

    func handle(
        notification: Notification
    ) {
        // هذا الحدث يستهلكه الـ root/tab container في المشروع.
        // إذا كان مشروعك يعرض InstallPreview عبر Navigation/Sheet،
        // اجعل الـ root container يستقبل:
        //
        // .kindaOpenInstallPreview
        //
        // ويعرض InstallPreviewView مباشرة.
        //
        // لا يتم فتح LibraryView أو SigningView هنا.
    }
}
