import Foundation
import UIKit
import FirebaseCore
import WhatScoreKit
#if canImport(WidgetKit)
import WidgetKit
#endif

private extension Bundle {
    var analyticsID: String {
        guard let id = infoDictionary?["AnalyticsID"] as? String else {
            assertionFailure("AnalyticsID not found in Info.plist")
            return ""
        }
        return id
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        Analytics.configure(appID: Bundle.main.analyticsID)
        FirebaseApp.configure()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}
