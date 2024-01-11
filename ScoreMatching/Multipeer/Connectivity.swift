import Foundation
import MultipeerConnectivity

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
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func connect(to peer: MCPeerID) {
        self.serviceBrowser.invitePeer(peer, to: self.session, withContext: nil, timeout: 20)
    }
}

extension Connectivity: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {

        print("Received Invitation from peer: \(peerID.displayName)")

        invitationHandler(true, session)
    }
}

extension Connectivity: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found Peer")
        self.peers.insert(peerID)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost Peer")
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
        print("Data received from peer: \(peerID)")
        let jsonDecoder = JSONDecoder()
        if let decodedData = try? jsonDecoder.decode([CodableTeamData].self, from: data) {
            DispatchQueue.main.async {
                self.readOnlyData = decodedData
            }
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("PeerID: \(peerID) changed state \(state)")

        switch state {
            case .connected:
                print("PeerID: \(peerID) connected")
            case .connecting:
                print("PeerID: \(peerID) connecting")
            case .notConnected:
                print("PeerID: \(peerID) not connected")
            default:
                print("PeerID: \(peerID) Default?")
        }

        DispatchQueue.main.async { [weak self] in
            self?.connectedPeers = session.connectedPeers
        }
    }
}
