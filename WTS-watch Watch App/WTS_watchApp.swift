//
//  WTS_watchApp.swift
//  WTS-watch Watch App
//
//  Created by Matteo Comisso on 06/11/2025.
//

import SwiftUI
import SwiftData
import ScoreMatchingKit

@main
struct WTS_watch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Team.self, Interval.self, Game.self])
    }
}
