import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let session: WorkoutSession
    let debugLog: [String]
    let onDone: () -> Void

    @State private var isShowingDebugLog = false

    var body: some View {
        NavigationStack {
            SessionSummaryContent(session: session) {
                if !debugLog.isEmpty {
                    Section {
                        Button("View Debug Log") {
                            isShowingDebugLog = true
                        }
                    } footer: {
                        Text("Raw angle/activation numbers recorded during this session — for tuning exercise detection, not everyday use.")
                    }
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            .sheet(isPresented: $isShowingDebugLog) {
                DebugLogView(lines: debugLog)
            }
        }
    }
}
