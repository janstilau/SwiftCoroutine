import Foundation
import MultipeerConnectivity
/*
 /// Handles the discovery and data transport between systems.
 class ScanTransport: NSObject {
 private let systemNetworkName = "skynet"
 private let localSystemName: MCPeerID
 
 let session: MCSession
 private let serviceAdvertiser: MCNearbyServiceAdvertiser
 private let serviceBrowser: MCNearbyServiceBrowser
 
 let localSystem: ScanSystem
 var taskModel: ScanModel?
 
 init(localSystem: ScanSystem) {
 localSystemName = MCPeerID(displayName: localSystem.name)
 serviceAdvertiser = MCNearbyServiceAdvertiser(
 peer: localSystemName,
 discoveryInfo: nil,
 serviceType: systemNetworkName
 )
 serviceBrowser = MCNearbyServiceBrowser(peer: localSystemName, serviceType: systemNetworkName)
 session = MCSession(peer: localSystemName, securityIdentity: nil, encryptionPreference: .required)
 
 self.localSystem = localSystem
 
 super.init()
 
 // Set up the service session.
 session.delegate = self
 
 // Set up service advertiser.
 serviceAdvertiser.delegate = self
 serviceAdvertiser.startAdvertisingPeer()
 
 // Set up service browser.
 serviceBrowser.delegate = self
 serviceBrowser.startBrowsingForPeers()
 }
 
 deinit {
 session.delegate = nil
 serviceAdvertiser.stopAdvertisingPeer()
 serviceAdvertiser.delegate = nil
 serviceBrowser.stopBrowsingForPeers()
 serviceBrowser.delegate = nil
 }
 }
 
 /// Handles changes in connectivity and asynchronously receiving data.
 extension ScanTransport: MCSessionDelegate {
 /// Handles changes in session connectivity.
 func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
 /// If it's a change in connectivity of the local node, don't broadcast it.
 guard peerID.displayName != localSystem.name else { return }
 
 switch state {
 case .notConnected:
 NotificationCenter.default.post(name: .disconnected, object: peerID.displayName)
 case .connected:
 NotificationCenter.default.post(name: .connected, object: peerID.displayName)
 default: break
 }
 }
 
 /// Handles incoming data.
 func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
 }
 }
 
 // MARK: - Service advertiser delegate implementation.
 
 extension ScanTransport: MCNearbyServiceAdvertiserDelegate {
 func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
 print("ScanTransport service advertiser failed: \(error.localizedDescription)")
 }
 
 func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
 // Automatically accept session invitations from all bonjour peers.
 invitationHandler(true, session)
 }
 }
 
 // MARK: - Service broswer delegate implementation.
 
 extension ScanTransport: MCNearbyServiceBrowserDelegate {
 func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
 print("ScanTransport service browse failed: \(error.localizedDescription)")
 }
 
 func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
 // Automatically invite all found peers.
 browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
 }
 
 func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
 NotificationCenter.default.post(name: .disconnected, object: peerID.displayName)
 }
 }
 
 // MARK: - Required, unused `MCSessionDelegate` methods.
 
 extension ScanTransport {
 func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
 func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
 func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
 }
 */
