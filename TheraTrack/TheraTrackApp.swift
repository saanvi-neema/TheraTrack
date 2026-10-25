import SwiftUI
import SwiftData

@main
struct TheraTrackApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                WorkoutListView()
                    .tabItem { Label("Routines", systemImage: "figure.strengthtraining.traditional") }
                SessionHistoryView()
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            }
        }
        .modelContainer(for: [Workout.self, WorkoutSession.self])
    }
}
