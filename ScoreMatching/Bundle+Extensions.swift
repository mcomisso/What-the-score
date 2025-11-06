import Foundation

public extension Bundle {
    var versionNumber: String {
        guard let version = infoDictionary?["CFBundleShortVersionString"] as? String else {
            assertionFailure("CFBundleShortVersionString not found in Info.plist")
            return "Unknown"
        }
        return version
    }

    var buildNumber: String {
        guard let build = infoDictionary?["CFBundleVersion"] as? String else {
            assertionFailure("CFBundleVersion not found in Info.plist")
            return "0"
        }
        return build
    }

    var revenueCatApiKey: String {
        guard let key = infoDictionary?["RevenueCatAPIKey"] as? String else {
            assertionFailure("RevenueCatAPIKey not found in Info.plist")
            return ""
        }
        return key
    }
}
