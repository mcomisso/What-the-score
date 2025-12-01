import Foundation
import WhatScoreKit
import SwiftUI

struct EditView: View {

    @Bindable var team: Team
    @State private var originalName: String = ""

    var body: some View {
        List {
            TextField("Insert team name", text: $team.name)
                .foregroundColor(.accentColor)
            ColorPicker("Team color", selection: $team.resolvedColor)
        }
        .onAppear {
            originalName = team.name
        }
        .onDisappear {
            if team.name != originalName {
                Analytics.log(.teamRenamed)
            }
        }
    }
}

struct Previews_EditTeamName_Previews: PreviewProvider {
    static var previews: some View {
        EditView(team: Team(name: "Team name"))
    }
}
