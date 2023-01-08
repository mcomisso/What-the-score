import Foundation
import SwiftUI

struct TwitterButton: View {
    let username: String

    var body: some View {
        HStack {
            Image("twitter")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(.primary)
            Link("@\(username)", destination: URL(string: "https://twitter.com/\(username)")!)
        }
    }
}

struct TwitterButton_Preview: PreviewProvider {
    static var previews: some View {
        TwitterButton(username: "teomatteo89")
            .previewLayout(.sizeThatFits)
    }
}
