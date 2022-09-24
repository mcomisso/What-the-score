import Foundation
import SwiftUI

struct ReceiverModeView: View {
    @Binding var isReceiverMode: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ConnectivityView()
            Button {
                withAnimation {
                    isReceiverMode = false
                }
            } label: {
                Text("Exit receiver mode")
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}


struct ReceiverModeView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiverModeView(isReceiverMode: .constant(true))
    }
}
