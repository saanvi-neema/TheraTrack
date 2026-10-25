import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed workout sessions will show up here.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.workoutName)
                                        .font(.headline)
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionSummaryContent(session: session) { EmptyView() }
                    .navigationTitle("Session Summary")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
