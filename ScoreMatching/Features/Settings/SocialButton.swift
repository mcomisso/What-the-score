import Foundation
import SwiftUI

struct SocialButton: View {
    let username: String
    let url: URL
    let icon: Image

    var body: some View {
        Label {
            Link("Follow \(username)", destination: url)
        } icon: {
            icon
        }
    }
}

#Preview("Social") {
    SocialButton(username: "teomatteo", url: URL(string: "https://cool")!, icon: Image(.threads))
}
