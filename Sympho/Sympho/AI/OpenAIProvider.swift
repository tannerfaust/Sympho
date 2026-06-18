import Foundation

nonisolated struct OpenAIProvider: AIModelProvider {
    let apiKey: String
    var model = "gpt-5-mini"
    var endpoint = URL(string: "https://api.openai.com/v1/responses")!
    var session: URLSession = .shared

    func generate(_ request: AIProviderRequest) async throws -> AIProviderResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 90
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(RequestBody(
            model: model,
            instructions: request.instructions,
            input: try input(for: request),
            text: .init(format: .init(
                type: "json_schema",
                name: request.schemaName,
                strict: true,
                schema: request.schema
            ))
        ))

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.message)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw AIServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let payload = try JSONDecoder().decode(ResponseBody.self, from: data)
        let content = payload.output.compactMap(\.content).flatMap { $0 }
        guard let outputText = content
            .first(where: { $0.type == "output_text" })?
            .text,
            let outputData = outputText.data(using: .utf8)
        else {
            throw AIServiceError.invalidResponse
        }

        return AIProviderResponse(json: outputData, providerID: "openai", model: model)
    }

    private func input(for request: AIProviderRequest) throws -> String {
        let contextData = try JSONEncoder().encode(request.context)
        let context = String(data: contextData, encoding: .utf8) ?? "{}"
        return "User request:\n\(request.prompt)\n\nSympho workspace context:\n\(context)"
    }

    private struct RequestBody: Encodable {
        let model: String
        let instructions: String
        let input: String
        let text: TextConfiguration
    }

    private struct TextConfiguration: Encodable {
        let format: Format

        struct Format: Encodable {
            let type: String
            let name: String
            let strict: Bool
            let schema: AIJSONSchema
        }
    }

    private struct ResponseBody: Decodable {
        let output: [OutputItem]

        struct OutputItem: Decodable {
            let content: [Content]?
        }

        struct Content: Decodable {
            let type: String
            let text: String?
        }
    }

    private struct ErrorEnvelope: Decodable {
        let error: APIError

        struct APIError: Decodable {
            let message: String
        }
    }
}
