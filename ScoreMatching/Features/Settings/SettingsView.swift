import Foundation
import SwiftUI
import PDFKit
import SwiftData
import StoreKit
import WhatScoreKit

enum AppStorageValues {
    static let shouldKeepScreenAwake = "shouldKeepScreenAwake"
    static let shouldAllowNegativePoints = "shouldAllowNegativePoints"
    static let hasEnabledIntervals = "hasEnabledIntervals"
}

private enum SocialLinks {
    static let mastodon = URL(string: "https://mastodon.social/@teomatteo89")
    static let threads = URL(string: "https://www.threads.net/@matteo_comisso")
}

private enum AppLinks {
    static let myVinylPlus = URL(string: "https://apple.co/41yJhHM")
}

struct SettingsView: View {

    @Environment(\.dismiss) var dimiss
    @Environment(\.openURL) var openURL
    @Environment(\.requestReview) var requestReview
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]
    @Environment(\.modelContext) var modelContext

    @State private var isShowingNameChangeAlert: Bool = false
    @State private var isEditing: Bool = false
    @State private var showResetAlert: Bool = false
    @State private var showZeroScoreAlert: Bool = false
    @State private var pdfURL: URL?
    @State private var showShareSheet: Bool = false

    @AppStorage(AppStorageValues.shouldKeepScreenAwake)
    var shouldKeepScreenAwake: Bool = false

    @AppStorage(AppStorageValues.shouldAllowNegativePoints)
    var shouldAllowNegativePoints: Bool = false

    @AppStorage(AppStorageValues.hasEnabledIntervals)
    var hasEnabledIntervals: Bool = false

    @State var colorSelection: Color = .random

    var teamsSection: some View {
        ForEach(teams) { team in
            @Bindable var bindableTeam = team
            HStack {
                ColorPicker(selection: Binding(
                    get: {
                        print("📱 iOS Settings: ColorPicker GET for '\(team.name)'")
                        return bindableTeam.resolvedColor
                    },
                    set: { newColor in
                        print("📱 iOS Settings: ColorPicker SET for '\(team.name)' - NEW COLOR: \(newColor.toHex(alpha: false))")
                        bindableTeam.resolvedColor = newColor
                        // Immediately send to watch after color change
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            print("📱 iOS Settings: Triggering sendTeamDataToWatch after color change")
                            watchSyncCoordinator?.sendTeamDataToWatch()
                        }
                    }
                ), supportsOpacity: false) {
                    NavigationLink(destination: EditView(team: team)) {
                        Text(team.name)
                    }
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
                self.intervals.forEach { modelContext.delete($0) }
                Team.createBaseData(modelContext: modelContext)
                do {
                    try modelContext.save()
                    print("📱 iOS Settings: Reinitialized, sending data to watch...")
                    // Send to watch after save completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        watchSyncCoordinator?.sendTeamDataToWatch()
                    }
                } catch {
                    print("📱 iOS Settings: Failed to save after reinitialize: \(error)")
                }
            }
        } message: {
            Text("The app will delete teams, scores, and intervals, and start with \"Team A\" and \"Team B\".")
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
                do {
                    try modelContext.save()
                    // Send to watch after save completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        watchSyncCoordinator?.sendTeamDataToWatch()
                    }
                } catch {
                    print("📱 iOS Settings: Failed to save after reset: \(error)")
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
                            do {
                                try modelContext.save()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    watchSyncCoordinator?.sendTeamDataToWatch()
                                }
                            } catch {
                                print("📱 iOS Settings: Failed to save after adding team: \(error)")
                            }
                        }.buttonStyle(.borderless)
                    }

                    Section {
                        setZeroScoreButton

                        reinitialiseAppButton
                    }

                    Section("Export") {
                        Button {
                            generatePDF()
                        } label: {
                            Label("Export Scoreboard as PDF", systemImage: "doc.text")
                        }
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
                        .onChange(of: shouldKeepScreenAwake) { oldValue, newValue in
                            print("📱 iOS Settings: shouldKeepScreenAwake changed from \(oldValue) to \(newValue)")
                            let preferences: [String: Any] = [
                                "shouldKeepScreenAwake": newValue
                            ]
                            watchSyncCoordinator?.sendPreferences(preferences)
                        }
                    }



                    Section(footer: Text("Enable intervals to track scores by quarters, halves, or periods.")) {
                        Toggle(
                            "Use intervals",
                            isOn: $hasEnabledIntervals
                        )
                        .onChange(of: hasEnabledIntervals) { oldValue, newValue in
                            print("📱 iOS Settings: hasEnabledIntervals changed from \(oldValue) to \(newValue)")
                            let preferences: [String: Any] = [
                                "hasEnabledIntervals": newValue
                            ]
                            watchSyncCoordinator?.sendPreferences(preferences)
                        }
                        Toggle(
                            "Allow negative points",
                            isOn: $shouldAllowNegativePoints
                        )
                        .onChange(of: shouldAllowNegativePoints) { oldValue, newValue in
                            print("📱 iOS Settings: shouldAllowNegativePoints changed from \(oldValue) to \(newValue)")
                            let preferences: [String: Any] = [
                                "shouldAllowNegativePoints": newValue
                            ]
                            watchSyncCoordinator?.sendPreferences(preferences)
                        }
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
                        
                        if let mastodonURL = SocialLinks.mastodon {
                            SocialButton(
                                username: "Matteo on Mastodon",
                                url: mastodonURL,
                                icon: Image(.mastodon)
                            )
                        }

                        if let threadsURL = SocialLinks.threads {
                            SocialButton(
                                username: "Matteo on Threads",
                                url: threadsURL,
                                icon: Image(.threads)
                            )
                        }
                    }

                    // MARK: - Other Apps

                    Section(
                        header: Text("Other Apps"),
                        footer: Text("Check out my other apps on the App Store.")
                    ) {
                        if let myVinylPlusURL = AppLinks.myVinylPlus {
                            Link(destination: myVinylPlusURL) {
                                HStack {
                                    Image("MyVinylPlus")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 32, height: 32)
                                        .cornerRadius(8)
                                    Text("My Vinyl+")
                                }
                            }
                        }
                    }
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
            .sheet(isPresented: $showShareSheet) {
                if let pdfURL = pdfURL {
                    ShareSheet(items: [pdfURL])
                }
            }
        }
    }

    private func generatePDF() {
        guard let document = PDFCreator.generateScoreboardPDF(teams: teams, intervals: intervals) else {
            return
        }

        guard let url = PDFCreator.savePDFToTemporaryFile(document: document) else {
            return
        }

        pdfURL = url
        showShareSheet = true
    }

    func remove(_ indexSet: IndexSet) {
        // Ensure at least 2 teams remain
        guard teams.count - indexSet.count >= 2 else {
            return
        }

        for idx in indexSet {
            let team = teams[idx]
            modelContext.delete(team)
        }
        do {
            try modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                watchSyncCoordinator?.sendTeamDataToWatch()
            }
        } catch {
            print("📱 iOS Settings: Failed to save after removing team: \(error)")
        }
    }
}

// Share Sheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
}
