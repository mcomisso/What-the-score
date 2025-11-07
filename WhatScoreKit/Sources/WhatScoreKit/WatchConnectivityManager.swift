import Foundation
#if canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
import OSLog

private let logger = Logger(subsystem: "com.mcomisso.ScoreMatching.WhatScoreKit", category: "WatchConnectivity")

/// Manages bidirectional communication between iOS and watchOS apps
@Observable
public final class WatchConnectivityManager: NSObject, @unchecked Sendable {

    public nonisolated(unsafe) static let shared = WatchConnectivityManager()

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

    /// Callback for when team data is received (teams with colors and scores)
    public var onTeamDataReceived: (([[String: Any]]) -> Void)?

    override private init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            logger.info("🔄 WCSession activation initiated")
            print("🔄 WatchConnectivity: Activation initiated")
        } else {
            logger.warning("❌ WatchConnectivity is not supported on this device")
            print("❌ WatchConnectivity: Not supported on this device")
        }
    }

    // MARK: - Sending Data

    /// Send team data to the paired device using application context
    /// This ensures the paired device always has the latest team colors and scores
    public func sendTeamData(_ teams: [[String: Any]]) {
        guard let session = session else {
            logger.warning("❌ Cannot send team data: session not available")
            print("❌ WatchConnectivity: Cannot send team data - session not available")
            return
        }

        guard session.activationState == .activated else {
            logger.warning("❌ Cannot send team data: session not activated (state: \(session.activationState.rawValue))")
            print("❌ WatchConnectivity: Session not activated, state: \(session.activationState.rawValue)")
            return
        }

        let context: [String: Any] = ["teams": teams]

        do {
            try session.updateApplicationContext(context)
            logger.info("✅ Team data sent via application context: \(teams.count) teams")
            print("✅ WatchConnectivity: Sent \(teams.count) teams to paired device")
        } catch {
            logger.error("❌ Failed to send team data: \(error.localizedDescription)")
            print("❌ WatchConnectivity: Failed to send - \(error.localizedDescription)")
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
            logger.info("Session reachability changed: \(session.isReachable)")
        }
    }

    // MARK: - Receiving Messages

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        logger.info("Received message: \(message.keys)")

        // Extract notification and command
        let notification = message["notification"] as? String
        let command = message["command"] as? String

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

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
            let notificationString = context["notification"] as? String

            // Handle team data first (higher priority)
            if let teams = teamsData {
                print("📥 WatchConnectivity: Received \(teams.count) teams from paired device")
                self.onTeamDataReceived?(teams)
                logger.info("✅ Received team data from application context: \(teams.count) teams")
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
