import Foundation
import WhatScoreKit
import SwiftUI

struct EditView: View {

    @Bindable var team: Team
    @State private var originalName: String = ""

    var body: some View {
        List {
            TextField("Insert team name", text: $team.name)
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

#Preview {
    EditView(team: Team(name: "Team name"))
}
