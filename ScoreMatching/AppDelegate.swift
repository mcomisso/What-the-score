import Foundation
import TelemetryClient
import UIKit
import FirebaseCore
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

        let configuration = TelemetryManagerConfiguration(appID: Bundle.main.analyticsID)
        TelemetryManager.initialize(with: configuration)
        FirebaseApp.configure()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}

class Analytics {
    static func log(_ event: String) {
        TelemetryManager.send(event)
    }
}
