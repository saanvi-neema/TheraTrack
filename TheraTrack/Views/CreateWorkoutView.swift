import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CreateWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var workoutName = ""
    @State private var exerciseNames: [String] = []

    @State private var specialInstructions = ""
    @State private var isImportingDocument = false
    @State private var documentData: Data?
    @State private var documentFileName: String?

    @State private var isExtracting = false
    @State private var isPresentingReview = false
    @State private var extractedConstraints: [ExtractedConstraint] = []
    @State private var extractionErrorMessage: String?

    private var availableExercises: [DefaultExercise] {
        DefaultExercise.allCases.filter { !exerciseNames.contains($0.rawValue) }
    }

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

                    if !availableExercises.isEmpty {
                        Menu {
                            ForEach(availableExercises) { exercise in
                                Button(exercise.rawValue) {
                                    exerciseNames.append(exercise.rawValue)
                                }
                            }
                        } label: {
                            Label("Add Exercise", systemImage: "plus")
                        }
                    }
                }

                Section {
                    TextField(
                        "Special instructions from your PT",
                        text: $specialInstructions,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    if let documentFileName {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(documentFileName)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                self.documentFileName = nil
                                self.documentData = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Button {
                            isImportingDocument = true
                        } label: {
                            Label("Upload Document", systemImage: "doc.badge.plus")
                        }
                    }
                } header: {
                    Text("Personalize (Optional)")
                } footer: {
                    Text("Add PT instructions or upload an exercise sheet, or leave this blank to use default guidelines.")
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveTapped) {
                        if isExtracting {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!canSave || isExtracting)
                }
            }
            .fileImporter(
                isPresented: $isImportingDocument,
                allowedContentTypes: allowedDocumentTypes,
                onCompletion: handleDocumentImport
            )
            .sheet(isPresented: $isPresentingReview) {
                ConstraintReviewView(
                    exercises: exerciseNames,
                    constraints: extractedConstraints,
                    onConfirm: { finalConstraints in
                        isPresentingReview = false
                        performSave(constraints: finalConstraints)
                    },
                    onCancel: {
                        isPresentingReview = false
                    }
                )
            }
            .alert(
                "Extraction Failed",
                isPresented: Binding(
                    get: { extractionErrorMessage != nil },
                    set: { if !$0 { extractionErrorMessage = nil } }
                )
            ) {
                Button("Save Without Constraints") { performSave(constraints: []) }
                Button("Try Again", role: .cancel) {}
            } message: {
                Text(extractionErrorMessage ?? "")
            }
        }
    }

    private var allowedDocumentTypes: [UTType] {
        [.pdf, .jpeg, .png, .plainText]
    }

    private func handleDocumentImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let data = try? Data(contentsOf: url) {
            documentData = data
            documentFileName = url.lastPathComponent
        }
    }

    private func saveTapped() {
        let hasPersonalization = !specialInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || documentData != nil
        guard hasPersonalization else {
            performSave(constraints: [])
            return
        }
        Task { await extractAndReview() }
    }

    private func extractAndReview() async {
        isExtracting = true
        defer { isExtracting = false }

        do {
            var combinedText = specialInstructions
            if let documentData, let documentFileName,
               let documentText = try await DocumentTextExtractor.extractText(from: documentData, fileName: documentFileName) {
                combinedText += "\n\n" + documentText
            }

            extractedConstraints = try await ConstraintExtractionService.extractConstraints(
                from: combinedText,
                exercises: exerciseNames,
                apiKey: Secrets.groqAPIKey
            )
            isPresentingReview = true
        } catch {
            extractionErrorMessage = error.localizedDescription
        }
    }

    private func performSave(constraints: [ExtractedConstraint]) {
        let workout = Workout(name: workoutName.trimmingCharacters(in: .whitespaces))
        workout.exercises = exerciseNames.enumerated().map { index, name in
            Exercise(name: name, order: index)
        }

        let trimmedInstructions = specialInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.specialInstructions = trimmedInstructions.isEmpty ? nil : trimmedInstructions
        workout.documentData = documentData
        workout.documentFileName = documentFileName

        workout.constraints = constraints.enumerated().map { index, constraint in
            Constraint(exerciseName: constraint.exerciseName, text: constraint.text, order: index)
        }

        modelContext.insert(workout)
        dismiss()
    }
}

#Preview {
    CreateWorkoutView()
        .modelContainer(for: Workout.self, inMemory: true)
}
