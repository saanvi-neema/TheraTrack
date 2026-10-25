import Foundation

enum GroqClientError: LocalizedError {
    case requestFailed(statusCode: Int, message: String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode, let message):
            if let message { return "Groq request failed (\(statusCode)): \(message)" }
            return "Groq request failed with status \(statusCode)."
        case .emptyResponse:
            return "Groq returned an empty response."
        }
    }
}

struct GroqClient {
    var apiKey: String
    var model = "openai/gpt-oss-120b"

    func chatCompletion(systemPrompt: String, userPrompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.2,
            "response_format": ["type": "json_object"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            struct ErrorBody: Decodable { struct Inner: Decodable { let message: String }; let error: Inner }
            let message = try? JSONDecoder().decode(ErrorBody.self, from: data).error.message
            throw GroqClientError.requestFailed(statusCode: statusCode, message: message)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw GroqClientError.emptyResponse
        }
        return content
    }
}
