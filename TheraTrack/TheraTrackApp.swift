import SwiftUI
import SwiftData

@main
struct TheraTrackApp: App {
    var body: some Scene {
        WindowGroup {
            WorkoutListView()
        }
        .modelContainer(for: [Workout.self, WorkoutSession.self])
    }
}
