import Foundation
import TelemetryClient
import UIKit
import FirebaseCore

private extension Bundle {
    var analyticsID: String {
        let id = infoDictionary?["AnalyticsID"] as? String
        return id!
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
}

class Analytics {
    static func log(_ event: String) {
        TelemetryManager.send(event)
    }
}
