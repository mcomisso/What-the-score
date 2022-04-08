import Foundation
import SwiftUI
import PDFKit

struct SettingsView: View {

    @Environment(\.dismiss) var dimiss

    @Binding var teams: [TeamsData]

    @State var isShowingNameChangeAlert: Bool = false
    @State var selection: TeamsData.ID?

    @State var isEditing: Bool = false

    @SceneStorage("isReceiverMode") var isReceiverMode: Bool = false

    var body: some View {
        NavigationView {

            ZStack(alignment: .bottom) {
                List(selection: $selection) {
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
                    }

                    Section("Utils") {
                        Button("Reset scores") {
                            teams.forEach { team in
                                team.count = 0
                            }
                        }
                        NavigationLink(destination: ConnectivityView()) {
                            Text("Sync and view on network")
                        }

                        Button("Open receiver mode") {
                            isReceiverMode = true
                        }
                    }

//                    Section("Export") {
//                        Button("Generate PDF of scoreboard") { }.disabled(true)
//                    }.featureFlag(.exportScorecard)
                }

                Button("Dismiss") {
                    dimiss()
                }.buttonStyle(.borderedProminent)
                    .padding()
                
            }.navigationTitle("Settings")
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

        SettingsView(teams: .constant([TeamsData("Team A"),
                                       TeamsData("Team B")]))
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
