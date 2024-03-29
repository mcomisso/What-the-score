import SwiftUI
import StoreKit
#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftData

@main
struct ScoreMatchingApp: App {
//    @State private var connectivity = Connectivity()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("totalLaunches") var totalLaunches: Int = 1
    @Environment(\.requestReview) var requestReview
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage("shouldKeepScreenAwake")
    var shouldKeepScreenAwake: Bool = false

    var body: some Scene {
        WindowGroup {
            MainView()
//                .environment(connectivity)
                .onAppear {
                    requestReviewIfNeeded()
                    setAwakeState()
                }
                .onChange(of: scenePhase) { phase, _ in
                    onSceneActive(phase)
                    onSceneBackground(phase)
                }
                .onChange(of: shouldKeepScreenAwake, initial: false) { _, newValue in
                    UIApplication.shared.isIdleTimerDisabled = newValue
                }
        }.modelContainer(for: [Team.self])
    }

    private func setAwakeState() {
        UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake
    }

    private func onSceneBackground(_ phase: ScenePhase) {
        guard phase == .background else {
            return
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func onSceneActive(_ phase: ScenePhase) {
        guard phase == .active else {
            return
        }
        totalLaunches += 1
    }

    private func requestReviewIfNeeded() {
        if totalLaunches % 3 == 0 {
            requestReview()
        }
    }
}
