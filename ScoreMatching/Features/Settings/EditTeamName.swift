import Foundation
import WhatScoreKit
import SwiftUI

struct EditView: View {

    @Bindable var team: Team
    @State private var originalName: String = ""

    var body: some View {
        List {
            TextField("Insert team name", text: $team.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
            ColorPicker("Team color", selection: $team.resolvedColor)
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
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
