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

    /// Callback for when data changed notification is received
    public var onDataChanged: (() -> Void)?

    /// Callback for when reset command is received
    public var onResetScores: (() -> Void)?

    /// Callback for when reinitialize command is received
    public var onReinitializeApp: (() -> Void)?

    override private init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            logger.info("WCSession activation initiated")
        } else {
            logger.warning("WatchConnectivity is not supported on this device")
        }
    }

    // MARK: - Sending Notifications

    /// Notify the paired device that data has changed (CloudKit will sync actual data)
    public func sendDataChangedNotification() {
        guard let session = session else {
            logger.warning("Cannot send notification: session not available")
            return
        }

        let message: [String: Any] = ["notification": "dataChanged"]

        // Try immediate message first if reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                logger.error("Failed to send data changed notification: \(error.localizedDescription)")
            })
        }

        // Always update context as fallback for when app is not running
        do {
            try session.updateApplicationContext(message)
            logger.info("Data changed notification sent")
        } catch {
            logger.error("Failed to update application context: \(error.localizedDescription)")
        }
    }

    /// Send reset scores command to the paired device
    public func sendResetScores() {
        guard let session = session, session.isReachable else {
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
        guard let session = session, session.isReachable else {
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

extension WatchConnectivityManager: @preconcurrency WCSessionDelegate {

    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isSessionActivated = activationState == .activated

            if let error = error {
                logger.error("Session activation failed: \(error.localizedDescription)")
            } else {
                logger.info("Session activated successfully")
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
        logger.info("Received application context")

        // Extract notification
        let notification = applicationContext["notification"] as? String

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let notification = notification, notification == "dataChanged" {
                self.onDataChanged?()
                logger.info("Received data changed notification from application context")
            }
        }
    }
}
#endif
