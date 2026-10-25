import SwiftUI

struct LiveSessionView: View {
    let workout: Workout
    let onFinished: (WorkoutSession) -> Void

    @State private var viewModel: LiveSessionViewModel
    @State private var completedSession: WorkoutSession?

    init(workout: Workout, onFinished: @escaping (WorkoutSession) -> Void) {
        self.workout = workout
        self.onFinished = onFinished
        _viewModel = State(initialValue: LiveSessionViewModel(workout: workout))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(previewLayer: viewModel.previewLayer)
                .ignoresSafeArea()

            PoseOverlayView(points: viewModel.latestPoints)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Text(viewModel.currentExerciseName ?? (viewModel.isSessionComplete ? "All exercises complete!" : "Get in position…"))
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                    Spacer()

                    if viewModel.currentExerciseName != nil {
                        Text(repsLabel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding()

                if let feedback = viewModel.feedbackMessage {
                    Text(feedback)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                }

                Spacer()

                Button {
                    completedSession = viewModel.endSession()
                } label: {
                    Text("End Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.start()
            viewModel.announceCurrentExercise()
        }
        .onDisappear { viewModel.stop() }
        .fullScreenCover(item: $completedSession) { session in
            SessionSummaryView(session: session, debugLog: viewModel.debugHistory, onDone: { onFinished(session) })
        }
    }

    private var repsLabel: String {
        if let target = viewModel.currentRepTarget {
            return "Reps: \(viewModel.currentRepCount)/\(target)"
        }
        return "Reps: \(viewModel.currentRepCount)"
    }
}
