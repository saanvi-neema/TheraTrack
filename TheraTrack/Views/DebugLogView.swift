import SwiftUI

/// Temporary diagnostic screen: raw per-exercise numbers from a session, for tuning.
struct DebugLogView: View {
    let lines: [String]
    @State private var didCopy = false

    private var fullText: String { lines.joined(separator: "\n") }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 15, design: .monospaced))
                    }
                }
                .padding()
            }
            .navigationTitle("Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: fullText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        UIPasteboard.general.string = fullText
                        didCopy = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopy = false }
                    } label: {
                        Text(didCopy ? "Copied!" : "Copy All")
                    }
                }
            }
        }
    }
}
