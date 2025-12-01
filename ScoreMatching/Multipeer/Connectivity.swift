import Foundation
import WhatScoreKit
import MultipeerConnectivity
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "Connectivity")

@Observable
final class Connectivity: NSObject {

    private let devicePeerID = MCPeerID(displayName: UIDevice.current.name)
    private let serviceType = "com-scorekpr"

    private var session: MCSession
    private var serviceBrowser: MCNearbyServiceBrowser
    private var serviceAdvertiser: MCNearbyServiceAdvertiser

    var peers: Set<MCPeerID> = []
    var connectedPeers: [MCPeerID] = []

    @MainActor
    var readOnlyData: [CodableTeamData] = []

    override init() {

        self.session = MCSession(peer: devicePeerID, securityIdentity: nil, encryptionPreference: .required)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: devicePeerID, serviceType: serviceType)
        self.serviceAdvertiser = MCNearbyServiceAdvertiser.init(peer: devicePeerID, discoveryInfo: nil, serviceType: serviceType)
        super.init()

        self.session.delegate = self
        self.serviceAdvertiser.delegate = self
        self.serviceBrowser.delegate = self

        startObserving()
        startPublishing()
        Analytics.log(.multipeerStarted)
    }

    deinit {
        serviceBrowser.stopBrowsingForPeers()
        serviceAdvertiser.stopAdvertisingPeer()
    }

    func startPublishing() {
        serviceAdvertiser.startAdvertisingPeer()
    }

    func startObserving() {
        serviceBrowser.startBrowsingForPeers()
    }

    func send(data: Data) {
        if !peers.isEmpty {
            do {
                try session.send(data, toPeers: Array(peers), with: .reliable)
                Analytics.log(.multipeerDataSent, with: ["peer_count": "\(peers.count)"])
            } catch {
                logger.error("Failed to send data: \(error.localizedDescription)")
            }
        }
    }

    func connect(to peer: MCPeerID) {
        self.serviceBrowser.invitePeer(peer, to: self.session, withContext: nil, timeout: 20)
    }
}

extension Connectivity: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {

        logger.info("Received invitation from peer: \(peerID.displayName)")

        invitationHandler(true, session)
    }
}

extension Connectivity: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logger.info("Found peer: \(peerID.displayName)")
        self.peers.insert(peerID)
        Analytics.log(.multipeerPeerFound, with: ["total_peers": "\(peers.count)"])
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
        if peers.contains(peerID) {
            peers.remove(peerID)
        }
    }
}

extension Connectivity: MCSessionDelegate {
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {

    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {

    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {

    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        logger.info("Data received from peer: \(peerID.displayName)")
        let jsonDecoder = JSONDecoder()
        if let decodedData = try? jsonDecoder.decode([CodableTeamData].self, from: data) {
            Analytics.log(.multipeerDataReceived, with: ["team_count": "\(decodedData.count)"])
            DispatchQueue.main.async {
                self.readOnlyData = decodedData
            }
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger.info("Peer \(peerID.displayName) changed state to \(String(describing: state))")

        switch state {
            case .connected:
                logger.info("Peer \(peerID.displayName) connected")
                Analytics.log(.multipeerConnected, with: ["connected_peers": "\(session.connectedPeers.count)"])
            case .connecting:
                logger.info("Peer \(peerID.displayName) connecting")
            case .notConnected:
                logger.info("Peer \(peerID.displayName) not connected")
                Analytics.log(.multipeerDisconnected)
            @unknown default:
                logger.warning("Peer \(peerID.displayName) entered unknown state")
        }

        DispatchQueue.main.async { [weak self] in
            self?.connectedPeers = session.connectedPeers
        }
    }
}
