import Foundation

public extension Bundle {
    var versionNumber: String {
        infoDictionary!["CFBundleShortVersionString"] as! String
    }

    var buildNumber: String {
        infoDictionary!["CFBundleVersion"] as! String
    }

    var revenueCatApiKey: String {
        infoDictionary!["RevenueCatAPIKey"] as! String
    }
}
