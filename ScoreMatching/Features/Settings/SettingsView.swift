import Foundation
import SwiftUI
import PDFKit

struct SettingsView: View {

    @Environment(\.dismiss) var dimiss

    @Binding var teams: [TeamsData]

    @State private var isShowingNameChangeAlert: Bool = false
    @State private var selection: TeamsData.ID?
    @State private var isEditing: Bool = false
    @State private var showResetAlert: Bool = false

    @SceneStorage("isReceiverMode") var isReceiverMode: Bool = false

    var body: some View {
        NavigationView {

            VStack {
                List(selection: $selection) {
                    Section("Teams") {
                        ForEach($teams) { team in
                            ColorPicker(selection: team.color,
                                        supportsOpacity: false) {
                                NavigationLink(destination: EditView(team: team)) {
                                    Text(team.name.wrappedValue)
                                }
                            }
                        }.onDelete(perform: remove(_:))

                        Button("Add team") {
                            teams.append(TeamsData("Team \(teams.count + 1)"))
                        }.buttonStyle(.borderless)
                    }

                    Section("Utils") {
                        NavigationLink(destination: ConnectivityView()) {
                            Text("Broadcast to other devices")
                        }

                        Button("Receive scores from other devices") {
                            isReceiverMode = true
                        }
                    }

                    Section("Danger zone") {
                        Button("Reset scores", role: .destructive) {
                            showResetAlert.toggle()
                        }.alert("Are you sure?", isPresented: $showResetAlert) {
                            Button("Yes, reset scores", role: .destructive) {
                                let privateTeams = teams
                                privateTeams.forEach { $0.count = 0 }
                                self.teams = privateTeams
                            }
                        } message: {
                            Text("The score will be set to 0.")
                        }
                    }

                    #if DEBUG
                    Section("Export") {
                        Button("Generate PDF of scoreboard") { }
                    }
                    #endif
                }

                Button {
                    dimiss()
                } label: {
                    Text("Dismiss")
                        .frame(minWidth: 280, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
            }.navigationTitle("Settings")
                .background(Color(uiColor: UIColor.systemGroupedBackground))
        }
    }

    func remove(_ indexSet: IndexSet) {
        teams.remove(atOffsets: indexSet)
    }
}


struct Previews_SettingsView_Previews: PreviewProvider {
    @State static var color1: Color = .accentColor
    @State static var color2: Color = .accentColor

    static var previews: some View {
        SettingsView(teams: .constant([TeamsData("Team A"),
                                       TeamsData("Team B")]))
    }
}
