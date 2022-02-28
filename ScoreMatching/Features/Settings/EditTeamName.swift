//
//  EditTeamName.swift
//  ScoreMatching
//
//  Created by Matteo Comisso on 28/02/22.
//

import Foundation
import SwiftUI

struct EditView: View {

    @Binding var team: TeamsData

    var body: some View {
        List {
            TextField("Insert team name", text: $team.name)
                .foregroundColor(.accentColor)
//                .textFieldStyle(.roundedBorder)
            ColorPicker("Team color", selection: $team.color)
        }
    }
}

struct Previews_EditTeamName_Previews: PreviewProvider {
    static var previews: some View {
        EditView(team: .constant(.init("Team name")))
    }
}
