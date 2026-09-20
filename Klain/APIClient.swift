import Foundation

enum APIEvent {
    case text(String), usage(Usage), remaining(String)
}

struct APIClient {
    private func request(_ p: Provider, path: String) throws -> URLRequest {
        guard let url = URL(string: p.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) + path), url.scheme == "https", url.host != nil else { throw failure("Нужен корректный HTTPS URL") }
        var r = URLRequest(url: url)
        r.timeoutInterval = 120
        if !p.apiKey.isEmpty {
            r.setValue(p.kind == "anthropic" ? p.apiKey : "Bearer \(p.apiKey)", forHTTPHeaderField: p.kind == "anthropic" ? "x-api-key" : "Authorization")
        }
        if p.kind == "anthropic" { r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") }
        for h in p.headers ?? [] where !h.name.isEmpty { r.setValue(h.value, forHTTPHeaderField: h.name) }
        return r
    }
    private func failure(_ text: String) -> NSError { NSError(domain: "klain.API", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw failure("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0). Проверь ключ, лимиты, модель и поддержку вложений.") }
    }
    func models(provider: Provider) async throws -> [ModelEntry] {
        var result: [ModelEntry] = []
        var path = "/models"
        for _ in 0..<100 {
            let (data, response) = try await URLSession.shared.data(for: request(provider, path: path)); try validate(response)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let items = json["data"] as? [[String: Any]] else { throw failure("Провайдер не вернул список моделей. Добавь ID вручную.") }
            result += items.compactMap { item in guard let id = item["id"] as? String else { return nil }; return ModelEntry(id: id, name: item["display_name"] as? String ?? item["name"] as? String ?? id) }
            guard provider.kind == "anthropic", json["has_more"] as? Bool == true, let last = json["last_id"] as? String, let encoded = last.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { break }
            path = "/models?after_id=\(encoded)"
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
    }
    func balance(provider: Provider) async throws -> String {
        guard URL(string: provider.baseURL)?.host == "openrouter.ai" else { return "Баланс: нет данных API" }
        let (data, response) = try await URLSession.shared.data(for: request(provider, path: "/key")); try validate(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let info = json?["data"] as? [String: Any], let remaining = info["limit_remaining"] as? Double { return String(format: "Остаток лимита ключа: $%.4f", remaining) }
        return "Лимит ключа не задан; баланс счёта неизвестен"
    }
    func stream(chat: Chat, provider: Provider) -> AsyncThrowingStream<APIEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let anthropic = provider.kind == "anthropic"
                    var r = try request(provider, path: anthropic ? "/messages" : "/chat/completions")
                    r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    var body: [String: Any] = ["model": chat.model, "stream": true, "messages": try chat.messages.filter { $0.failed != true }.map { try message($0, provider: provider) }]
                    if anthropic { body["max_tokens"] = 8192 }
                    else { body["stream_options"] = ["include_usage": true] }
                    if let effort = chat.reasoning, effort != "default" {
                        if anthropic {
                            body["thinking"] = ["type": "adaptive"]
                            body["output_config"] = ["effort": effort == "xhigh" ? "max" : effort]
                        } else if URL(string: provider.baseURL)?.host == "openrouter.ai" {
                            body["reasoning"] = ["effort": effort == "max" ? "xhigh" : effort]
                        } else { body["reasoning_effort"] = effort == "max" ? "xhigh" : effort }
                    }
                    r.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: r); try validate(response)
                    if let http = response as? HTTPURLResponse {
                        let names = ["x-ratelimit-remaining-tokens", "anthropic-ratelimit-tokens-remaining", "anthropic-ratelimit-input-tokens-remaining", "anthropic-ratelimit-output-tokens-remaining"]
                        let values = names.compactMap { name in http.value(forHTTPHeaderField: name).map { "\(name): \($0)" } }
                        if !values.isEmpty { continuation.yield(.remaining(values.joined(separator: "\n") + "\nОстаток окна rate limit, не баланс аккаунта.")) }
                    }
                    var usage = Usage()
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8), let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        if let error = json["error"] as? [String: Any] { throw failure(error["message"] as? String ?? "Ошибка потока API") }
                        if anthropic {
                            if let delta = json["delta"] as? [String: Any], let text = delta["text"] as? String { continuation.yield(.text(text)) }
                            let start = (json["message"] as? [String: Any])?["usage"] as? [String: Any]
                            if let u = start ?? json["usage"] as? [String: Any] {
                                if let input = u["input_tokens"] as? Int { usage.input = input + (u["cache_read_input_tokens"] as? Int ?? 0) + (u["cache_creation_input_tokens"] as? Int ?? 0) }
                                if let output = u["output_tokens"] as? Int { usage.output = output }
                                if let cached = u["cache_read_input_tokens"] as? Int { usage.cached = cached }
                                continuation.yield(.usage(usage))
                            }
                        } else {
                            if let choices = json["choices"] as? [[String: Any]], let delta = choices.first?["delta"] as? [String: Any], let text = delta["content"] as? String { continuation.yield(.text(text)) }
                            if let u = json["usage"] as? [String: Any] {
                                usage.input = u["prompt_tokens"] as? Int ?? usage.input
                                usage.output = u["completion_tokens"] as? Int ?? usage.output
                                usage.cached = (u["prompt_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int ?? usage.cached
                                usage.cost = u["cost"] as? Double ?? usage.cost
                                continuation.yield(.usage(usage))
                            }
                        }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    private func message(_ m: Message, provider: Provider) throws -> [String: Any] {
        let anthropic = provider.kind == "anthropic"
        var parts: [[String: Any]] = m.text.isEmpty ? [] : [["type": "text", "text": m.text]]
        for a in m.attachments {
            let base64 = a.data.base64EncodedString()
            let encoded = "data:\(a.mime);base64,\(base64)"
            if anthropic && (a.mime.hasPrefix("image/") || a.mime == "application/pdf") {
                parts.append(["type": a.mime == "application/pdf" ? "document" : "image", "source": ["type": "base64", "media_type": a.mime, "data": base64]])
            } else if a.mime.hasPrefix("image/") { parts.append(["type": "image_url", "image_url": ["url": encoded]]) }
            else if a.mime.hasPrefix("video/") && provider.kind == "google" { parts.append(["type": "video_url", "video_url": ["url": encoded]]) }
            else if a.mime.hasPrefix("video/") && URL(string: provider.baseURL)?.host == "openrouter.ai" { parts.append(["type": "video_url", "video_url": ["url": encoded]]) }
            else if a.mime == "application/pdf" && URL(string: provider.baseURL)?.host == "openrouter.ai" { parts.append(["type": "file", "file": ["filename": a.name, "file_data": encoded]]) }
            else if let text = String(data: a.data, encoding: .utf8) { parts.append(["type": "text", "text": "Файл: \(a.name)\n\(text)"]) }
            else { throw failure("\(a.name): формат не поддержан этим подключением.") }
        }
        return ["role": m.role, "content": m.attachments.isEmpty ? m.text as Any : parts as Any]
    }
}
