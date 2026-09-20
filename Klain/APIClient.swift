import Foundation

struct APIClient {
    func models(provider: Provider) async throws -> [String] {
        guard let url = URL(string: provider.baseURL + "/models"), url.scheme == "https" else { throw URLError(.badURL) }
        var r = URLRequest(url: url); r.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: r)
        try validate(response)
        struct Result: Decodable { struct Model: Decodable { let id: String }; let data: [Model] }
        return try JSONDecoder().decode(Result.self, from: data).data.map(\.id).sorted()
    }
    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw NSError(domain: "API", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "API вернул HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0). Проверь ключ, модель и поддержку вложений."]) }
    }
    func stream(chat: Chat, provider: Provider?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
              do {
                guard let p = provider, let url = URL(string: p.baseURL + "/chat/completions"), url.scheme == "https" else { continuation.finish(throwing: URLError(.badURL)); return }
                var request = URLRequest(url: url); request.httpMethod = "POST"; request.setValue("Bearer \(p.apiKey)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let messages: [[String: Any]] = try chat.messages.map { m in
                    var parts: [[String: Any]] = [["type": "text", "text": m.text]]
                    for a in m.attachments {
                        let encoded = "data:\(a.mime);base64,\(a.data.base64EncodedString())"
                        if a.mime.hasPrefix("image/") { parts.append(["type": "image_url", "image_url": ["url": encoded]]) }
                        else if a.mime.hasPrefix("video/") && URL(string: p.baseURL)?.host == "openrouter.ai" { parts.append(["type": "video_url", "video_url": ["url": encoded]]) }
                        else if a.mime == "application/pdf" && URL(string: p.baseURL)?.host == "openrouter.ai" { parts.append(["type": "file", "file": ["filename": a.name, "file_data": encoded]]) }
                        else if let text = String(data: a.data, encoding: .utf8) { parts.append(["type": "text", "text": "Файл: \(a.name)\n\(text)"]) }
                        else { throw NSError(domain: "Attachment", code: 1, userInfo: [NSLocalizedDescriptionKey: "Формат \(a.name) не поддерживается этим подключением. Видео/PDF: используй совместимую модель OpenRouter."]) }
                    }
                    return ["role": m.role, "content": m.attachments.isEmpty ? m.text as Any : parts as Any]
                }
                let body: [String: Any] = ["model": chat.model, "stream": true, "messages": messages]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                try validate(response)
                for try await line in bytes.lines where line.hasPrefix("data: ") { let value = String(line.dropFirst(6)); if value == "[DONE]" { break }; if let d = value.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let choices = json["choices"] as? [[String: Any]], let delta = choices.first?["delta"] as? [String: Any], let content = delta["content"] as? String { continuation.yield(content) } }
                continuation.finish()
              } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
