import Foundation
import SwiftUI
import PDFKit
import SwiftData
import StoreKit

struct SettingsView: View {

    @Environment(\.dismiss) var dimiss
    @Environment(\.openURL) var openURL
    @Environment(\.requestReview) var requestReview

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Environment(\.modelContext) var modelContext

    @State private var isShowingNameChangeAlert: Bool = false
    //    @State private var selection: Team.ID?
    @State private var isEditing: Bool = false
    @State private var showResetAlert: Bool = false
    @State private var showZeroScoreAlert: Bool = false

    @AppStorage("shouldKeepScreenAwake") 
    var shouldKeepScreenAwake: Bool = false

    @State var colorSelection: Color = .random
    @SceneStorage("isReceiverMode") var isReceiverMode: Bool = false

    var teamsSection: some View {
        ForEach(teams) { team in
            @Bindable var team = team
            ColorPicker(selection: $team.resolvedColor,
                        supportsOpacity: false) {
                NavigationLink(destination: EditView(team: team)) {
                    Text(team.name)
                }
            }
        }
        .onDelete(perform: remove(_:))
    }

    var body: some View {
        NavigationView {

            VStack {
                List {
                    Section("Teams") {

                        teamsSection

                        Button("Add team") {
                            let team = Team(name: "Team \(teams.count + 1)")
                            modelContext.insert(team)
                        }.buttonStyle(.borderless)
                    }

                    Section {
                        Button("Set scores to 0") {
                            showZeroScoreAlert.toggle()
                        }
                        .alert("Are you sure?", isPresented: $showZeroScoreAlert) {
                            Button("Yes, reset scores", role: .destructive) {
                                self.teams.forEach {
                                    $0.score = []
                                }
                            }
                        } message: {
                            Text("Each team score will be set to 0.")
                        }
                        
                        Button("Reinitialize app", role: .destructive) {
                            showResetAlert.toggle()
                        }
                        .alert("Are you sure?", isPresented: $showResetAlert) {
                            Button("Yes, reset scores", role: .destructive) {
                                self.teams.forEach { modelContext.delete($0) }
                            }
                        } message: {
                            Text("The app will delete teams and scores, and start with \"Team A\" and \"Team B\".")
                        }
                    }

                    Section(header: Text("Preferences"), footer: Text("This will prevent your device from dimming the screen and going to sleep.")) {
                        Toggle("Keep screen awake", isOn: $shouldKeepScreenAwake)
                    }

//                    Section("Connectivity") {
//                        NavigationLink(destination: ConnectivityView()) {
//                            Text("Broadcast to other devices")
//                        }
//
//                        Button("Receive scores from other devices") {
//                            isReceiverMode = true
//                        }
//                    }

                    let aboutHeader = Text("About")
                    let aboutFooter = Text("Feel free to get in touch via any of the above socials for feedback or feature requests.")
                    Section(
                        header: aboutHeader,
                        footer: aboutFooter
                    ) {
                        
                        Button {
                            Task {
                                requestReview()
                            }
                        } label: {
                            Label("Rate the app (Thank you! 🙏)", systemImage: "star")
                                .symbolVariant(.fill)
                        }
                        
                        SocialButton(
                            username: "Matteo on Mastodon",
                            url: URL(string: "https://mastodon.social/@teomatteo89")!,
                            icon: Image(.mastodon)
                        )
                        
                        SocialButton(
                            username: "Matteo on Threads",
                            url: URL(string: "https://www.threads.net/@matteo_comisso")!,
                            icon: Image(.threads)
                        )
//                        
//                        Button {
//                            openURL(mailURL)
//                        } label: {
//                            Label("Submit feedback / feature request", systemImage: "envelope")
//                        }
                    }
#if DEBUG
                    Section("Export") {
                        Button("Generate PDF of scoreboard") { }
                    }
#endif
                }
            }
            .navigationTitle("Settings")
            .background(Color(uiColor: UIColor.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Material.regular)
                        .overlay {
                            Button {
                                dimiss()
                            } label: {
                                Text("Dismiss")
                                    .frame(minWidth: 280, minHeight: 32)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                        .frame(height: 64)
                        .ignoresSafeArea()
            }
        }
    }

    func remove(_ indexSet: IndexSet) {
        for idx in indexSet {
            let team = teams[idx]
            modelContext.delete(team)
        }
    }
//
//    var mailURL: URL {
//        let subject = "What the score (\(Bundle.main.buildNumber)) support request"
//        let body = """
//
//
//----- Please reply above this line -----
//Build number: \(Bundle.main.buildNumber)
//Version: \(Bundle.main.versionNumber)
//Locale: \(Locale.current.description)
//"""
//        let mailURL: URL = URL(string: "mailto:whatthescore@mcomisso.me")!
//        var components = URLComponents(url: mailURL, resolvingAgainstBaseURL: false)
//        let items = [
//            URLQueryItem(name: "body", value: body),
//            URLQueryItem(name: "subject", value: subject)
//        ]
//
//        components?.queryItems = items
//
//        return components!.url!
//    }
}

#Preview {
    SettingsView()
}
