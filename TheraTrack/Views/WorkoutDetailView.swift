import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isImportingDocument = false
    @State private var isExtracting = false
    @State private var isPresentingReview = false
    @State private var extractedConstraints: [ExtractedConstraint] = []
    @State private var extractionErrorMessage: String?
    @State private var isPresentingDeleteConfirmation = false
    @State private var isPresentingSession = false

    private var availableExercises: [DefaultExercise] {
        let existingNames = Set(workout.exercises.map(\.name))
        return DefaultExercise.allCases.filter { !existingNames.contains($0.rawValue) }
    }

    private var instructionsBinding: Binding<String> {
        Binding(
            get: { workout.specialInstructions ?? "" },
            set: { workout.specialInstructions = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                Button {
                    isPresentingSession = true
                } label: {
                    Text("Start Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(workout.exercises.isEmpty)
            }

            Section("Workout Name") {
                TextField("Workout Name", text: $workout.name)
            }

            Section("Exercises") {
                ForEach(workout.exercises.sorted { $0.order < $1.order }) { exercise in
                    Text(exercise.name)
                }
                .onDelete { offsets in
                    let sorted = workout.exercises.sorted { $0.order < $1.order }
                    for index in offsets {
                        modelContext.delete(sorted[index])
                    }
                }

                if !availableExercises.isEmpty {
                    Menu {
                        ForEach(availableExercises) { exercise in
                            Button(exercise.rawValue) {
                                let newOrder = (workout.exercises.map(\.order).max() ?? -1) + 1
                                workout.exercises.append(Exercise(name: exercise.rawValue, order: newOrder))
                            }
                        }
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }

            Section {
                TextField("Special instructions from your PT", text: instructionsBinding, axis: .vertical)
                    .lineLimit(3...6)

                if let documentFileName = workout.documentFileName {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text(documentFileName)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            workout.documentFileName = nil
                            workout.documentData = nil
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

                Button {
                    Task { await reExtract() }
                } label: {
                    if isExtracting {
                        ProgressView()
                    } else {
                        Text("Save Personalization")
                    }
                }
                .disabled(isExtracting || (instructionsBinding.wrappedValue.isEmpty && workout.documentData == nil))
            } header: {
                Text("Personalize")
            } footer: {
                Text("Add PT instructions or upload a document, then tap Save Personalization to review the constraints before they're applied.")
            }

            Section {
                Button("Delete Workout", role: .destructive) {
                    isPresentingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .fileImporter(
            isPresented: $isImportingDocument,
            allowedContentTypes: [.pdf, .jpeg, .png, .plainText],
            onCompletion: handleDocumentImport
        )
        .sheet(isPresented: $isPresentingReview) {
            ConstraintReviewView(
                exercises: workout.exercises.map(\.name),
                constraints: extractedConstraints,
                onConfirm: { finalConstraints in
                    isPresentingReview = false
                    replaceConstraints(with: finalConstraints)
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
            Button("OK", role: .cancel) {}
        } message: {
            Text(extractionErrorMessage ?? "")
        }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive) {
                modelContext.delete(workout)
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $isPresentingSession) {
            LiveSessionView(workout: workout) { session in
                modelContext.insert(session)
                isPresentingSession = false
            }
        }
    }

    private func handleDocumentImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let data = try? Data(contentsOf: url) {
            workout.documentData = data
            workout.documentFileName = url.lastPathComponent
        }
    }

    private func reExtract() async {
        isExtracting = true
        defer { isExtracting = false }

        do {
            var combinedText = workout.specialInstructions ?? ""
            if let documentData = workout.documentData, let documentFileName = workout.documentFileName,
               let documentText = try await DocumentTextExtractor.extractText(from: documentData, fileName: documentFileName) {
                combinedText += "\n\n" + documentText
            }

            extractedConstraints = try await ConstraintExtractionService.extractConstraints(
                from: combinedText,
                exercises: workout.exercises.map(\.name),
                apiKey: Secrets.groqAPIKey
            )
            isPresentingReview = true
        } catch {
            extractionErrorMessage = error.localizedDescription
        }
    }

    private func replaceConstraints(with newConstraints: [ExtractedConstraint]) {
        for constraint in workout.constraints {
            modelContext.delete(constraint)
        }
        workout.constraints = newConstraints.enumerated().map { index, constraint in
            Constraint(exerciseName: constraint.exerciseName, text: constraint.text, order: index)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(name: "Morning Routine"))
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
