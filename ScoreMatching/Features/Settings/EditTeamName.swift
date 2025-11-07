import Foundation
import WhatScoreKit
import SwiftUI

struct EditView: View {

    @Bindable var team: Team

    var body: some View {
        List {
            TextField("Insert team name", text: $team.name)
                .foregroundColor(.accentColor)
            ColorPicker("Team color", selection: $team.resolvedColor)
        }
    }
}

struct Previews_EditTeamName_Previews: PreviewProvider {
    static var previews: some View {
        EditView(team: Team(name: "Team name"))
    }
}
