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
                    Text(viewModel.currentExerciseName ?? "Get in position…")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                    Spacer()

                    Text("Reps: \(viewModel.currentRepCount)")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding()

                Spacer()

                if let feedback = viewModel.feedbackMessage {
                    Text(feedback)
                        .font(.subheadline.weight(.semibold))
                        .padding()
                        .background(.orange.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }

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
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .fullScreenCover(item: $completedSession) { session in
            SessionSummaryView(session: session, onDone: { onFinished(session) })
        }
    }
}
