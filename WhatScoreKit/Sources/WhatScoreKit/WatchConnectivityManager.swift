import Foundation
#if canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
import OSLog

private let logger = Logger(subsystem: "com.mcomisso.ScoreMatching.WhatScoreKit", category: "WatchConnectivity")

/// Manages bidirectional communication between iOS and watchOS apps
@Observable
public final class WatchConnectivityManager: NSObject, @unchecked Sendable {

    public static let shared = WatchConnectivityManager()

    private var session: WCSession?

    /// Indicates if Watch Connectivity is supported and activated
    public var isSessionActivated = false
    public var isReachable = false

    /// Callback for when session becomes activated
    public var onSessionActivated: (() -> Void)?

    /// Callback for when data changed notification is received
    public var onDataChanged: (() -> Void)?

    /// Callback for when reset command is received
    public var onResetScores: (() -> Void)?

    /// Callback for when reinitialize command is received
    public var onReinitializeApp: (() -> Void)?

    /// Callback for when team and interval data is received
    public var onDataReceived: ((_ teams: [[String: Any]], _ intervals: [[String: Any]]) -> Void)?

    /// Legacy callback for backward compatibility (deprecated, use onDataReceived)
    public var onTeamDataReceived: (([[String: Any]]) -> Void)?

    /// Callback for when preferences are received
    public var onPreferencesReceived: ((_ preferences: [String: Any]) -> Void)?

    override private init() {
        super.init()

        #if os(iOS)
        print("📱 WatchConnectivityManager: Initializing on iOS")
        #elseif os(watchOS)
        print("⌚️ WatchConnectivityManager: Initializing on watchOS")
        #endif

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            print("🔄 WatchConnectivity: About to activate session...")
            session?.activate()
            logger.info("🔄 WCSession activation initiated")
            print("🔄 WatchConnectivity: Activation initiated")
        } else {
            logger.warning("❌ WatchConnectivity is not supported on this device")
            print("❌ WatchConnectivity: Not supported on this device")
        }
    }

    // MARK: - Sending Data

    /// Send team and interval data to the paired device
    /// Uses immediate message delivery when reachable for real-time updates,
    /// falls back to application context for background delivery
    public func sendTeamData(_ teams: [[String: Any]], intervals: [[String: Any]] = []) {
        guard let session = session else {
            logger.warning("❌ Cannot send data: session not available")
            print("❌ WatchConnectivity: Cannot send data - session not available")
            return
        }

        guard session.activationState == .activated else {
            logger.warning("❌ Cannot send data: session not activated (state: \(session.activationState.rawValue))")
            print("❌ WatchConnectivity: Session not activated, state: \(session.activationState.rawValue)")
            return
        }

        let message: [String: Any] = [
            "teams": teams,
            "intervals": intervals
        ]

        // Log current reachability status
        let reachabilityStatus = session.isReachable ? "✅ REACHABLE" : "⏸️ NOT REACHABLE"
        print("🔍 WatchConnectivity: Current session status - \(reachabilityStatus)")
        logger.info("Current session reachability: \(session.isReachable)")

        // Try immediate message first if reachable for real-time updates
        if session.isReachable {
            print("📤 WatchConnectivity: Attempting to send via immediate message (real-time)...")
            session.sendMessage(message, replyHandler: nil, errorHandler: { [weak self] error in
                logger.error("❌ Failed to send immediate message: \(error.localizedDescription)")
                print("❌ WatchConnectivity: Failed to send immediate message - \(error.localizedDescription)")
                // Fallback to application context on error
                self?.updateTeamDataContext(session: session, message: message, teams: teams, intervals: intervals)
            })
            logger.info("✅ Data sent via immediate message (real-time): \(teams.count) teams, \(intervals.count) intervals")
            print("✅ WatchConnectivity: Sent \(teams.count) teams, \(intervals.count) intervals via immediate message")
        } else {
            // Use application context for background delivery when not reachable
            logger.info("⏳ Watch not reachable, using application context for background delivery")
            print("⏳ WatchConnectivity: Watch not reachable, using application context")
            updateTeamDataContext(session: session, message: message, teams: teams, intervals: intervals)
        }
    }

    /// Update application context with team data (fallback or background delivery)
    private func updateTeamDataContext(session: WCSession, message: [String: Any], teams: [[String: Any]], intervals: [[String: Any]]) {
        do {
            try session.updateApplicationContext(message)
            logger.info("✅ Data sent via application context: \(teams.count) teams, \(intervals.count) intervals")
            print("✅ WatchConnectivity: Sent \(teams.count) teams, \(intervals.count) intervals via application context")
        } catch {
            logger.error("❌ Failed to update application context: \(error.localizedDescription)")
            print("❌ WatchConnectivity: Failed to update application context - \(error.localizedDescription)")
        }
    }

    // MARK: - Sending Notifications

    /// Notify the paired device that data has changed (CloudKit will sync actual data)
    public func sendDataChangedNotification() {
        guard let session = session else {
            logger.warning("Cannot send notification: session not available")
            return
        }

        // Check session is activated
        guard session.activationState == .activated else {
            logger.warning("Cannot send notification: session not activated (state: \(session.activationState.rawValue))")
            return
        }

        let message: [String: Any] = ["notification": "dataChanged"]

        // Try immediate message first if reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                logger.error("Failed to send data changed notification via message: \(error.localizedDescription)")
                // Fallback to application context on error
                self.updateNotificationContext(session: session, message: message)
            })
            logger.info("Data changed notification sent via message")
        } else {
            // Use application context for background delivery when not reachable
            updateNotificationContext(session: session, message: message)
        }
    }

    /// Update application context with notification (only called when message fails or not reachable)
    private func updateNotificationContext(session: WCSession, message: [String: Any]) {
        do {
            try session.updateApplicationContext(message)
            logger.info("Data changed notification sent via application context")
        } catch {
            logger.error("Failed to update application context: \(error.localizedDescription)")
        }
    }

    /// Send reset scores command to the paired device
    public func sendResetScores() {
        guard let session = session else {
            logger.warning("Cannot send reset command: session not available")
            return
        }

        guard session.activationState == .activated else {
            logger.warning("Cannot send reset command: session not activated")
            return
        }

        guard session.isReachable else {
            logger.warning("Cannot send reset command: session not reachable")
            return
        }

        let message: [String: Any] = ["command": "resetScores"]

        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            logger.error("Failed to send reset command: \(error.localizedDescription)")
        })
    }

    /// Send reinitialize app command to the paired device
    public func sendReinitializeApp() {
        guard let session = session else {
            logger.warning("Cannot send reinitialize command: session not available")
            return
        }

        guard session.activationState == .activated else {
            logger.warning("Cannot send reinitialize command: session not activated")
            return
        }

        guard session.isReachable else {
            logger.warning("Cannot send reinitialize command: session not reachable")
            return
        }

        let message: [String: Any] = ["command": "reinitializeApp"]

        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            logger.error("Failed to send reinitialize command: \(error.localizedDescription)")
        })
    }

    // MARK: - Sending Preferences

    /// Send preferences update to the paired device
    /// - Parameter preferences: Dictionary of preference keys and values to sync
    public func sendPreferences(_ preferences: [String: Any]) {
        guard let session = session else {
            logger.warning("Cannot send preferences: session not available")
            print("❌ WatchConnectivity: Cannot send preferences - session not available")
            return
        }

        guard session.activationState == .activated else {
            logger.warning("Cannot send preferences: session not activated (state: \(session.activationState.rawValue))")
            print("❌ WatchConnectivity: Session not activated, state: \(session.activationState.rawValue)")
            return
        }

        let message: [String: Any] = ["preferences": preferences]

        // Log current reachability status
        let reachabilityStatus = session.isReachable ? "✅ REACHABLE" : "⏸️ NOT REACHABLE"
        print("🔍 WatchConnectivity: Sending preferences - \(reachabilityStatus)")
        logger.info("Sending preferences, reachability: \(session.isReachable)")

        // Try immediate message first if reachable for real-time updates
        if session.isReachable {
            print("📤 WatchConnectivity: Sending preferences via immediate message...")
            session.sendMessage(message, replyHandler: nil, errorHandler: { [weak self] error in
                logger.error("❌ Failed to send preferences via message: \(error.localizedDescription)")
                print("❌ WatchConnectivity: Failed to send preferences - \(error.localizedDescription)")
                // Fallback to application context on error
                self?.updatePreferencesContext(session: session, message: message, preferences: preferences)
            })
            logger.info("✅ Preferences sent via immediate message: \(preferences.keys)")
            print("✅ WatchConnectivity: Sent preferences via immediate message: \(preferences.keys)")
        } else {
            // Use application context for background delivery when not reachable
            logger.info("⏳ Watch not reachable, using application context for preferences")
            print("⏳ WatchConnectivity: Watch not reachable, using application context for preferences")
            updatePreferencesContext(session: session, message: message, preferences: preferences)
        }
    }

    /// Update application context with preferences (fallback or background delivery)
    private func updatePreferencesContext(session: WCSession, message: [String: Any], preferences: [String: Any]) {
        do {
            try session.updateApplicationContext(message)
            logger.info("✅ Preferences sent via application context: \(preferences.keys)")
            print("✅ WatchConnectivity: Sent preferences via application context: \(preferences.keys)")
        } catch {
            logger.error("❌ Failed to update application context with preferences: \(error.localizedDescription)")
            print("❌ WatchConnectivity: Failed to update application context with preferences - \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {


    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        DispatchQueue.main.async {
            let wasActivated = self.isSessionActivated
            self.isSessionActivated = activationState == .activated

            if let error = error {
                logger.error("❌ Session activation failed: \(error.localizedDescription)")
                print("❌ WatchConnectivity: Session activation failed - \(error.localizedDescription)")
            } else if activationState == .activated {
                logger.info("✅ Session activated successfully")
                print("✅ WatchConnectivity: Session activated successfully")
                // Notify listeners if this is the first time we're activated
                if !wasActivated {
                    print("🔔 WatchConnectivity: Calling onSessionActivated callback")
                    self.onSessionActivated?()
                }
            }
        }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("Session became inactive")
    }

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        logger.info("Session deactivated, reactivating...")
        session.activate()
    }
    #endif

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            let status = session.isReachable ? "✅ REACHABLE" : "⏸️ NOT REACHABLE"
            logger.info("Session reachability changed: \(status)")
            print("🔄 WatchConnectivity: Session reachability changed: \(status)")
        }
    }

    // MARK: - Receiving Messages

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        logger.info("📨 Received immediate message with keys: \(message.keys)")
        print("📨 WatchConnectivity: Received immediate message with keys: \(message.keys)")

        // WatchConnectivity data is safe to pass across isolation boundaries (ObjC NSDictionary)
        nonisolated(unsafe) let msg = message

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Extract data types from message
            let teamsData = msg["teams"] as? [[String: Any]]
            let intervalsData = msg["intervals"] as? [[String: Any]]
            let notification = msg["notification"] as? String
            let command = msg["command"] as? String
            let preferences = msg["preferences"] as? [String: Any]

            // Handle team and interval data (real-time sync)
            if let teams = teamsData {
                let intervals = intervalsData ?? []
                print("📥 WatchConnectivity: Received \(teams.count) teams, \(intervals.count) intervals via immediate message")

                // Call callback if set
                if self.onDataReceived != nil {
                    self.onDataReceived?(teams, intervals)
                    logger.info("✅ Received data from immediate message: \(teams.count) teams, \(intervals.count) intervals")
                } else {
                    self.onTeamDataReceived?(teams)
                    logger.info("✅ Received team data from immediate message (legacy): \(teams.count) teams")
                }
            }

            // Handle preferences
            if let preferences = preferences {
                print("📥 WatchConnectivity: Received preferences via immediate message: \(preferences.keys)")
                self.onPreferencesReceived?(preferences)
                logger.info("✅ Received preferences from immediate message: \(preferences.keys)")
            }

            // Handle notifications
            if let notification = notification {
                switch notification {
                case "dataChanged":
                    self.onDataChanged?()
                    logger.info("Received data changed notification")
                default:
                    logger.warning("Unknown notification: \(notification)")
                }
            }

            // Handle commands
            if let command = command {
                switch command {
                case "resetScores":
                    self.onResetScores?()
                    logger.info("Received reset scores command")
                case "reinitializeApp":
                    self.onReinitializeApp?()
                    logger.info("Received reinitialize app command")
                default:
                    logger.warning("Unknown command: \(command)")
                }
            }
        }
    }

    // MARK: - Receiving Application Context

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        logger.info("Received application context with keys: \(applicationContext.keys)")

        // WatchConnectivity data is safe to pass across isolation boundaries (ObjC NSDictionary)
        nonisolated(unsafe) let context = applicationContext

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Extract data on main queue
            let teamsData = context["teams"] as? [[String: Any]]
            let intervalsData = context["intervals"] as? [[String: Any]]
            let notificationString = context["notification"] as? String
            let preferences = context["preferences"] as? [String: Any]

            // Handle team and interval data (higher priority)
            if let teams = teamsData {
                let intervals = intervalsData ?? []
                print("📥 WatchConnectivity: Received \(teams.count) teams, \(intervals.count) intervals from paired device")

                // Call new callback if set, otherwise fall back to legacy callback
                if self.onDataReceived != nil {
                    self.onDataReceived?(teams, intervals)
                    logger.info("✅ Received data from application context: \(teams.count) teams, \(intervals.count) intervals")
                } else {
                    self.onTeamDataReceived?(teams)
                    logger.info("✅ Received team data from application context (legacy): \(teams.count) teams")
                }
            }

            // Handle preferences
            if let preferences = preferences {
                print("📥 WatchConnectivity: Received preferences from application context: \(preferences.keys)")
                self.onPreferencesReceived?(preferences)
                logger.info("✅ Received preferences from application context: \(preferences.keys)")
            }

            // Handle notifications
            if let notification = notificationString, notification == "dataChanged" {
                self.onDataChanged?()
                logger.info("Received data changed notification from application context")
            }
        }
    }
}
#endif
