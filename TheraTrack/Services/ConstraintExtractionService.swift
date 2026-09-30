import Foundation

enum ConstraintExtractionService {
    static func extractConstraints(
        from text: String,
        exercises: [String],
        apiKey: String
    ) async throws -> [ExtractedConstraint] {
        let systemPrompt = """
        You are a physical therapy assistant. Extract safety-relevant exercise constraints \
        from the therapist notes provided, such as range-of-motion limits, movement \
        restrictions, or modified exercise instructions.

        The workout includes these exercises: \(exercises.joined(separator: ", ")).

        Respond with ONLY JSON in this exact shape, no other text:
        {"constraints": [{"exercise": "<one of the exercise names above, or null if it applies to the whole workout>", "text": "<short, specific constraint>"}]}

        If the notes mention no relevant constraints, respond with {"constraints": []}.
        """

        let client = GroqClient(apiKey: apiKey)
        let raw = try await client.chatCompletion(systemPrompt: systemPrompt, userPrompt: text)

        guard let data = raw.data(using: .utf8) else {
            throw GroqClientError.emptyResponse
        }

        struct Response: Decodable {
            struct Item: Decodable {
                let exercise: String?
                let text: String
            }
            let constraints: [Item]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.constraints.map { ExtractedConstraint(exerciseName: $0.exercise, text: $0.text) }
    }
}
