import Foundation
import SwiftUI

struct EditView: View {

    @Binding var team: TeamsData

    var body: some View {
        TextField(team.name, text: $team.name)
            .textFieldStyle(.roundedBorder)
            .padding()
    }
}

struct SettingsView: View {

    @Environment(\.dismiss) var dimiss

    @Binding var teams: [TeamsData]
    @State var isShowingNameChangeAlert: Bool = false

    @State var selection: TeamsData.ID?

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
                }

                Button("Add team") {
                    self.teams.append(TeamsData("Team \(teams.count + 1)"))
                }
            }


            Button("Dismiss") {
                dimiss()
            }
        }
        }
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
