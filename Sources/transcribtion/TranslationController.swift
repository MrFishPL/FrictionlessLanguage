import AppKit
import Foundation

@available(macOS 14.4, *)
final class TranslationController {
    private let requestQueue = DispatchQueue(label: "transcribtion.translation.request")
    private var apiKey: String?
    private var didShowAuthError = false

    func requestApiKeyIfNeeded(completion: @escaping (Bool) -> Void) {
        if let apiKey = apiKey ?? EnvLoader.loadOpenAIKey(), !apiKey.isEmpty {
            self.apiKey = apiKey
            completion(true)
            return
        }

        ApiKeySetupCoordinator.shared.ensureKeys(required: [.openAI]) { [weak self] success in
            guard let self else { return }
            guard success, let apiKey = EnvLoader.loadOpenAIKey(), !apiKey.isEmpty else {
                completion(false)
                return
            }
            self.apiKey = apiKey
            completion(true)
        }
    }

    func translate(
        fragment: String,
        context: String,
        targetLanguage: Language,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        requestQueue.async { [weak self] in
            guard let self else { return }
            self.requestApiKeyIfNeeded { [weak self] success in
                guard let self else { return }
                guard success, let apiKey = self.apiKey ?? EnvLoader.loadOpenAIKey() else {
                    self.dispatchResult(.failure(TranslationError.missingApiKey), completion: completion)
                    return
                }
                self.performTranslation(
                    apiKey: apiKey,
                    fragment: fragment,
                    context: context,
                    targetLanguage: targetLanguage,
                    completion: completion
                )
            }
        }
    }

    private func performTranslation(
        apiKey: String,
        fragment: String,
        context: String,
        targetLanguage: Language,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            dispatchResult(.failure(TranslationError.invalidRequest), completion: completion)
            return
        }

        let prompt = """
What this fragment of text or a word "\(fragment)" means in context of this text "\(context)" in language "\(targetLanguage.rawValue)" - do translation. If the selection is a single word, translate only that single word. Output only the translated phrase without quotes, comments, or extra characters.
"""

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "translation": [
                    "type": "string",
                    "description": "Translation of the fragment in the requested language."
                ]
            ],
            "required": ["translation"],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "model": "gpt-5.2",
            "input": [
                [
                    "role": "system",
                    "content": "You are a translation assistant. Return JSON that matches the schema. The translation must contain only the translated phrase, no quotes, comments, or extra characters."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "translation",
                    "schema": schema,
                    "strict": true
                ]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            dispatchResult(.failure(TranslationError.invalidRequest), completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.dispatchResult(.failure(error), completion: completion)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                self.handleAuthError()
                self.dispatchResult(.failure(TranslationError.authError), completion: completion)
                return
            }

            guard let data else {
                self.dispatchResult(.failure(TranslationError.emptyResponse), completion: completion)
                return
            }

            do {
                let translation = try self.parseTranslation(from: data)
                self.dispatchResult(.success(translation), completion: completion)
            } catch {
                self.dispatchResult(.failure(error), completion: completion)
            }
        }

        task.resume()
    }

    private func parseTranslation(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw TranslationError.invalidResponse
        }

        if let error = dict["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw TranslationError.apiError(message)
        }

        guard let output = dict["output"] as? [[String: Any]] else {
            throw TranslationError.invalidResponse
        }

        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content {
                if let type = part["type"] as? String, type == "output_text",
                   let text = part["text"] as? String,
                   let translation = parseTranslationText(text) {
                    return translation
                }
                if let type = part["type"] as? String, type == "refusal" {
                    throw TranslationError.refused
                }
            }
        }

        throw TranslationError.invalidResponse
    }

    private func parseTranslationText(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = json as? [String: Any],
              let translation = dict["translation"] as? String else {
            return nil
        }
        return translation
    }

    private func dispatchResult(_ result: Result<String, Error>, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func handleAuthError() {
        guard !didShowAuthError else { return }
        didShowAuthError = true
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "There was an error. Is your OpenAI token correct?"
            alert.informativeText = "Flungus will now quit. Please check your OpenAI API key."
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            EnvLoader.removeOpenAIKey()
            NSApplication.shared.terminate(nil)
        }
    }

    // API key setup handled by SetupWindowController.
}

private enum TranslationError: LocalizedError {
    case missingApiKey
    case invalidRequest
    case invalidResponse
    case emptyResponse
    case authError
    case refused
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "OpenAI API key missing."
        case .invalidRequest:
            return "Invalid translation request."
        case .invalidResponse:
            return "Invalid translation response."
        case .emptyResponse:
            return "Empty translation response."
        case .authError:
            return "OpenAI authentication failed."
        case .refused:
            return "Translation request was refused."
        case .apiError(let message):
            return message
        }
    }
}
