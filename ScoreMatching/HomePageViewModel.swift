//
//  File.swift
//  ScoreMatching
//
//  Created by Matteo Comisso on 26/02/22.
//

import Foundation
import SwiftUI

@Observable
class ViewModel: Equatable {
    static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
        lhs.teamsViewModels == rhs.teamsViewModels
    }

    var teamsViewModels: [TeamsData] = []

    var intervals: [Interval] = []

    init() {
        teamsViewModels = ["Team A", "Team B"]
            .compactMap { TeamsData($0) }
    }

    func addInterval() {
        // Save current interval

        let copy = teamsViewModels
        let interval = Interval(id: 0, points: copy)
        intervals.append(interval)
    }

    func removeInterval(_ index: Int) {
        intervals.remove(at: index)
    }
}
