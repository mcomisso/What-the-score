import Foundation
import SwiftUI

struct ReceiverModeView: View {
    @Binding var isReceiverMode: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ConnectivityView()
            Button {
                withAnimation(.smooth) {
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


#Preview {
    ReceiverModeView(isReceiverMode: .constant(true))
}
