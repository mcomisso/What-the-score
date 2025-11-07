import Foundation
import WatchConnectivity
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "WatchConnectivity")

/// Manages bidirectional communication between iOS and watchOS apps
@Observable
final class WatchConnectivityManager: NSObject {

    static let shared = WatchConnectivityManager()

    private var session: WCSession?

    /// Indicates if Watch Connectivity is supported and activated
    var isSessionActivated = false
    var isReachable = false

    /// Callback for when teams data is received
    var onTeamsReceived: (([CodableTeamData]) -> Void)?

    /// Callback for when intervals data is received
    var onIntervalsReceived: (([CodableIntervalData]) -> Void)?

    /// Callback for when settings are received
    var onSettingsReceived: (([String: Any]) -> Void)?

    /// Callback for when reset command is received
    var onResetScores: (() -> Void)?

    /// Callback for when reinitialize command is received
    var onReinitializeApp: (() -> Void)?

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

    // MARK: - Sending Data

    /// Send teams data to the paired device
    func sendTeams(_ teams: [CodableTeamData]) {
        guard let session = session, session.isReachable else {
            logger.warning("Cannot send teams: session not reachable")
            updateApplicationContext(with: teams)
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(teams)
            let message: [String: Any] = ["teams": data]

            session.sendMessage(message, replyHandler: { reply in
                logger.info("Teams sent successfully, reply: \(String(describing: reply))")
            }, errorHandler: { error in
                logger.error("Failed to send teams: \(error.localizedDescription)")
                // Fallback to application context
                self.updateApplicationContext(with: teams)
            })
        } catch {
            logger.error("Failed to encode teams: \(error.localizedDescription)")
        }
    }

    /// Send intervals data to the paired device
    func sendIntervals(_ intervals: [CodableIntervalData]) {
        guard let session = session, session.isReachable else {
            logger.warning("Cannot send intervals: session not reachable")
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(intervals)
            let message: [String: Any] = ["intervals": data]

            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                logger.error("Failed to send intervals: \(error.localizedDescription)")
            })
        } catch {
            logger.error("Failed to encode intervals: \(error.localizedDescription)")
        }
    }

    /// Send settings to the paired device
    func sendSettings(_ settings: [String: Any]) {
        guard let session = session, session.isReachable else {
            logger.warning("Cannot send settings: session not reachable")
            return
        }

        let message: [String: Any] = ["settings": settings]

        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            logger.error("Failed to send settings: \(error.localizedDescription)")
        })
    }

    /// Send reset scores command to the paired device
    func sendResetScores() {
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
    func sendReinitializeApp() {
        guard let session = session, session.isReachable else {
            logger.warning("Cannot send reinitialize command: session not reachable")
            return
        }

        let message: [String: Any] = ["command": "reinitializeApp"]

        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            logger.error("Failed to send reinitialize command: \(error.localizedDescription)")
        })
    }

    // MARK: - Application Context (Background Transfer)

    /// Update application context with teams data for background transfer
    private func updateApplicationContext(with teams: [CodableTeamData]) {
        guard let session = session else { return }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(teams)
            let context: [String: Any] = ["teams": data]

            try session.updateApplicationContext(context)
            logger.info("Application context updated with teams data")
        } catch {
            logger.error("Failed to update application context: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
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
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("Session deactivated, reactivating...")
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            logger.info("Session reachability changed: \(session.isReachable)")
        }
    }

    // MARK: - Receiving Messages

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        logger.info("Received message: \(message.keys)")

        DispatchQueue.main.async {
            // Handle teams data
            if let teamsData = message["teams"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let teams = try decoder.decode([CodableTeamData].self, from: teamsData)
                    self.onTeamsReceived?(teams)
                    logger.info("Decoded \(teams.count) teams")
                } catch {
                    logger.error("Failed to decode teams: \(error.localizedDescription)")
                }
            }

            // Handle intervals data
            if let intervalsData = message["intervals"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let intervals = try decoder.decode([CodableIntervalData].self, from: intervalsData)
                    self.onIntervalsReceived?(intervals)
                    logger.info("Decoded \(intervals.count) intervals")
                } catch {
                    logger.error("Failed to decode intervals: \(error.localizedDescription)")
                }
            }

            // Handle settings data
            if let settings = message["settings"] as? [String: Any] {
                self.onSettingsReceived?(settings)
                logger.info("Received settings update")
            }

            // Handle commands
            if let command = message["command"] as? String {
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

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        logger.info("Received application context")

        DispatchQueue.main.async {
            if let teamsData = applicationContext["teams"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let teams = try decoder.decode([CodableTeamData].self, from: teamsData)
                    self.onTeamsReceived?(teams)
                    logger.info("Decoded \(teams.count) teams from application context")
                } catch {
                    logger.error("Failed to decode teams from context: \(error.localizedDescription)")
                }
            }
        }
    }
}
