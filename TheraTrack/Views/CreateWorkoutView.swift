import SwiftUI
import SwiftData

struct CreateWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var workoutName = ""
    @State private var exerciseNames: [String] = []
    @State private var newExerciseName = ""

    private var canSave: Bool {
        !workoutName.trimmingCharacters(in: .whitespaces).isEmpty && !exerciseNames.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Name") {
                    TextField("e.g. Morning Routine", text: $workoutName)
                }

                Section("Exercises") {
                    ForEach(exerciseNames, id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { offsets in
                        exerciseNames.remove(atOffsets: offsets)
                    }

                    HStack {
                        TextField("e.g. Sit-to-Stand", text: $newExerciseName)
                            .onSubmit(addExercise)
                        Button("Add", action: addExercise)
                            .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        exerciseNames.append(trimmed)
        newExerciseName = ""
    }

    private func save() {
        let workout = Workout(name: workoutName.trimmingCharacters(in: .whitespaces))
        workout.exercises = exerciseNames.enumerated().map { index, name in
            Exercise(name: name, order: index)
        }
        modelContext.insert(workout)
        dismiss()
    }
}

#Preview {
    CreateWorkoutView()
        .modelContainer(for: Workout.self, inMemory: true)
}
