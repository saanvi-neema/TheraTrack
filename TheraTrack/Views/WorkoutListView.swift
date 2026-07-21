import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Query(sort: \Workout.createdAt, order: .reverse) private var workouts: [Workout]
    @State private var isPresentingCreateWorkout = false

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Tap + to create your first workout.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            VStack(alignment: .leading) {
                                Text(workout.name)
                                Text("\(workout.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCreateWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingCreateWorkout) {
                CreateWorkoutView()
            }
        }
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: Workout.self, inMemory: true)
}
