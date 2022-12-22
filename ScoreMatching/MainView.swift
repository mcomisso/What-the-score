import Foundation
import SwiftUI

struct MainView: View {
    @SceneStorage("isReceiverMode")
    var isReceiverMode: Bool = false

    var body: some View {
        if isReceiverMode {
            ReceiverModeView(isReceiverMode: $isReceiverMode)
                .onAppear {
                    Analytics.log("receiverModeLaunch")
                }
        } else {
            ContentView()
        }
    }
}
