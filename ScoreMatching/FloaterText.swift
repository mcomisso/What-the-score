import Foundation
import SwiftUI

struct FloaterText: View {

    @Binding var text: String?

    var body: some View {
        if let text = text {
            VStack {
                Text(text)
                    .font(.subheadline)
            }.padding()
                .background(.thickMaterial,
                            in: RoundedRectangle(cornerRadius: 16))
                .padding()
                .shadow(radius: 16)
        } else {
            EmptyView()
        }
    }
}
