import Foundation
import SwiftUI
import PDFKit
import SwiftData
import StoreKit

enum AppStorageValues {
    static let shouldKeepScreenAwake = "shouldKeepScreenAwake"
    static let shouldAllowNegativePoints = "shouldAllowNegativePoints"
    static let hasEnabledIntervals = "hasEnabledIntervals"
}

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

    @AppStorage(AppStorageValues.shouldKeepScreenAwake)
    var shouldKeepScreenAwake: Bool = false
    
    @AppStorage(AppStorageValues.shouldAllowNegativePoints)
    var shouldAllowNegativePoints: Bool = false
    
    @AppStorage(AppStorageValues.hasEnabledIntervals)
    var hasEnabledIntervals: Bool = false

    @State var colorSelection: Color = .random

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

    var reinitialiseAppButton: some View {
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

    var setZeroScoreButton: some View {
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
    }

    var body: some View {
        NavigationView {

            VStack {
                List {
                    // MARK: - Teams

                    Section("Teams") {

                        teamsSection

                        Button("Add team") {
                            let team = Team(name: "Team \(teams.count + 1)")
                            modelContext.insert(team)
                        }.buttonStyle(.borderless)
                    }

                    Section {
                        setZeroScoreButton

                        reinitialiseAppButton
                    }
                    
                    // MARK: - Preferences

                    let preferencesHeader = Text("Preferences")
                    let preferencesFooter = Text("This will prevent your device from dimming the screen and going to sleep.")
                    Section(
                        header: preferencesHeader,
                        footer: preferencesFooter
                    ) {
                        Toggle(
                            "Keep screen awake",
                            isOn: $shouldKeepScreenAwake
                        )
                    }



                    Section {
                        Toggle(
                            "Use intervals",
                            isOn: $hasEnabledIntervals
                        )
                        Toggle(
                            "Allow negative points",
                            isOn: $shouldAllowNegativePoints
                        )
                    }

                    // MARK: - About

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
                    }
#if DEBUG
                    Section("Export") {
                        Button("Generate PDF of scoreboard") { }
                    }
#endif
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") {
                        dimiss()
                    }
                }
            }
        }
    }

    func remove(_ indexSet: IndexSet) {
        for idx in indexSet {
            let team = teams[idx]
            modelContext.delete(team)
        }
    }
}

#Preview {
    SettingsView()
}
