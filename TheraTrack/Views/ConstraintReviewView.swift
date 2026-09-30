import SwiftUI

struct ConstraintReviewView: View {
    let exercises: [String]
    @State private var constraints: [ExtractedConstraint]
    let onConfirm: ([ExtractedConstraint]) -> Void
    let onCancel: () -> Void

    init(
        exercises: [String],
        constraints: [ExtractedConstraint],
        onConfirm: @escaping ([ExtractedConstraint]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.exercises = exercises
        self._constraints = State(initialValue: constraints)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                if constraints.isEmpty {
                    ContentUnavailableView(
                        "No Constraints Found",
                        systemImage: "checkmark.shield",
                        description: Text("We didn't detect any specific restrictions. Default guidelines will be used.")
                    )
                } else {
                    Section("Review these before starting your workout") {
                        ForEach($constraints) { $constraint in
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Applies to", selection: Binding(
                                    get: { constraint.exerciseName ?? "Whole Workout" },
                                    set: { constraint.exerciseName = $0 == "Whole Workout" ? nil : $0 }
                                )) {
                                    Text("Whole Workout").tag("Whole Workout")
                                    ForEach(exercises, id: \.self) { name in
                                        Text(name).tag(name)
                                    }
                                }
                                TextField("Constraint", text: $constraint.text, axis: .vertical)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            constraints.remove(atOffsets: offsets)
                        }
                    }
                }

                Section {
                    Button {
                        constraints.append(ExtractedConstraint(exerciseName: nil, text: ""))
                    } label: {
                        Label("Add Constraint", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Review Constraints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        let cleaned = constraints.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                        onConfirm(cleaned)
                    }
                }
            }
        }
    }
}

#Preview {
    ConstraintReviewView(
        exercises: ["Sit-to-Stand", "Shoulder Abduction"],
        constraints: [
            ExtractedConstraint(exerciseName: "Shoulder Abduction", text: "Max 90° range of motion"),
            ExtractedConstraint(exerciseName: nil, text: "Move slowly, avoid sudden movements")
        ],
        onConfirm: { _ in },
        onCancel: {}
    )
}
