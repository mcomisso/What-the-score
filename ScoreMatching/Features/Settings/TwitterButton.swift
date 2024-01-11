import Foundation
import SwiftUI

struct SocialButton: View {
    let username: String
    let url: URL
    let icon: Image

    var body: some View {
        HStack {
            icon
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(.primary)
            Link(
                "Follow \(username)",
                destination: url
            )
        }
    }
}

#Preview("Social") {
    SocialButton(username: "teomatteo", url: URL(string: "https://cool")!, icon: Image(.threads))
}
