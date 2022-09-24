import Foundation
import SwiftUI
import MultipeerConnectivity

struct ConnectivityView: View {

    @EnvironmentObject var connectivity: Connectivity
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @ViewBuilder
    var connectedView: some View {
        if verticalSizeClass == .regular {
            VStack(spacing: 0) {
                ForEach(connectivity.readOnlyData) { element in
                    TapButton(score:.constant(element.score),
                              color: .constant(element.color),
                              name: .constant(element.name),
                              lastTapped: .constant(nil),
                              lastTimeTapped: .constant(Date()))
                    .background(element.color)
                    .colorInvert()
                    .colorInvert()
                }
            }.ignoresSafeArea()
        } else {
            HStack(spacing: 0) {
                ForEach(connectivity.readOnlyData) { element in
                    TapButton(score:.constant(element.score),
                              color: .constant(element.color),
                              name: .constant(element.name),
                              lastTapped: .constant(nil),
                              lastTimeTapped: .constant(Date()))
                    .background(element.color)
                    .colorInvert()
                    .colorInvert()
                }
            }.ignoresSafeArea()
        }
    }

    var searchingView: some View {

        List {
            Section("Found") {
                ForEach(Array(connectivity.peers), id: \.displayName) { peer in
                    Button {
                        connectivity.connect(to: peer)
                    } label: {
                        Text(peer.displayName)
                    }
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }

            Section("Connected") {
                if connectivity.connectedPeers.isEmpty {
                    Text("Select a device in the found list to connect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(connectivity.connectedPeers), id: \.displayName) { peer in
                        Text(peer.displayName)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack {
            if !connectivity.connectedPeers.isEmpty {
                connectedView
            } else {
                searchingView
            }
        }
    }
}
