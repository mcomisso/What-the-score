import Foundation
import TelemetryClient

/// Analytics helper for tracking user interactions and feature usage.
/// Uses TelemetryDeck for privacy-focused analytics.
///
/// Event naming convention: `category.action` (e.g., "team.created", "settings.changed")
/// Parameters are optional key-value pairs for additional context.
public enum Analytics {

    // MARK: - Event Categories

    public enum Event: String, Sendable {
        // App Lifecycle
        case appLaunched = "app.launched"
        case appBecameActive = "app.became_active"
        case appFirstLaunch = "app.first_launch"
        case reviewPromptShown = "app.review_prompt_shown"
        case reviewRequested = "app.review_requested"

        // Team Management
        case teamCreated = "team.created"
        case teamDeleted = "team.deleted"
        case teamRenamed = "team.renamed"
        case teamColorChanged = "team.color_changed"

        // Game Session
        case gameStarted = "game.started"
        case gameEnded = "game.ended"
        case scoresReset = "game.scores_reset"
        case appReinitialized = "game.app_reinitialized"

        // Intervals Feature
        case intervalsEnabled = "intervals.enabled"
        case intervalsDisabled = "intervals.disabled"
        case intervalCreated = "interval.created"
        case intervalDeleted = "interval.deleted"
        case intervalsViewed = "intervals.viewed"

        // Settings & Preferences
        case settingsOpened = "settings.opened"
        case preferenceChanged = "settings.preference_changed"
        case negativePointsEnabled = "settings.negative_points_enabled"
        case negativePointsDisabled = "settings.negative_points_disabled"
        case keepAwakeEnabled = "settings.keep_awake_enabled"
        case keepAwakeDisabled = "settings.keep_awake_disabled"

        // Export
        case pdfExportStarted = "export.pdf_started"
        case pdfExportCompleted = "export.pdf_completed"
        case pdfExportShared = "export.pdf_shared"

        // Multipeer Connectivity
        case multipeerStarted = "multipeer.started"
        case multipeerPeerFound = "multipeer.peer_found"
        case multipeerConnected = "multipeer.connected"
        case multipeerDisconnected = "multipeer.disconnected"
        case multipeerDataSent = "multipeer.data_sent"
        case multipeerDataReceived = "multipeer.data_received"

        // Watch
        case watchSyncSent = "watch.sync_sent"
        case watchSyncReceived = "watch.sync_received"
        case watchAppLaunched = "watch.app_launched"

        // Widget
        case widgetScoreIncrement = "widget.score_increment"
        case widgetLaunchedApp = "widget.launched_app"
    }

    // MARK: - Configuration

    /// Default TelemetryDeck app ID for What the Score
    /// This is used when Analytics.configure() is called without an ID (e.g., from Widget)
    private static let defaultAppID = "A2B016DF-35D6-4C92-8DA4-C333E3ABD791"

    private static var isConfigured = false

    /// Configure TelemetryDeck with your app ID.
    /// Call this once at app launch (in AppDelegate or App init).
    public static func configure(appID: String) {
        guard !isConfigured else { return }
        let configuration = TelemetryManagerConfiguration(appID: appID)
        TelemetryManager.initialize(with: configuration)
        isConfigured = true
    }

    /// Ensures TelemetryDeck is configured before sending events.
    /// Uses the default app ID if not already configured.
    private static func ensureConfigured() {
        if !isConfigured {
            configure(appID: defaultAppID)
        }
    }

    // MARK: - Logging Methods

    /// Log an event without parameters
    public static func log(_ event: Event) {
        ensureConfigured()
        TelemetryManager.send(event.rawValue)
    }

    /// Log an event with additional parameters
    public static func log(_ event: Event, with parameters: [String: String]) {
        ensureConfigured()
        TelemetryManager.send(event.rawValue, with: parameters)
    }

    /// Log a raw event string (for backwards compatibility or custom events)
    public static func log(_ event: String) {
        ensureConfigured()
        TelemetryManager.send(event)
    }

    /// Log a raw event string with parameters
    public static func log(_ event: String, with parameters: [String: String]) {
        ensureConfigured()
        TelemetryManager.send(event, with: parameters)
    }
}
