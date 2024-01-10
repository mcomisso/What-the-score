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

struct TwitterButton: View {
    let username: String

    var body: some View {
        HStack {
            Image(.twitter)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(.primary)
            Link("@\(username)", destination: URL(string: "https://twitter.com/\(username)")!)
        }
    }
}

#Preview("Social") {
    SocialButton(username: "teomatteo", url: URL(string: "https://cool")!, icon: Image(.threads))
}

struct TwitterButton_Preview: PreviewProvider {
    static var previews: some View {
        TwitterButton(username: "teomatteo89")
            .previewLayout(.sizeThatFits)
    }
}
