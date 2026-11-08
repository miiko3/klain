import Foundation

struct Provider: Identifiable, Codable, Equatable {
    var id = UUID(); var name: String; var baseURL: String; var apiKey: String
    var kind: String? = "custom"
    var slug: String? = "custom"
    var models: [ModelEntry]? = []
    var headers: [HeaderEntry]? = []
}
struct ModelEntry: Identifiable, Codable, Equatable {
    var id: String; var name: String
    var outputModalities: [String]?
    var inputModalities: [String]?

    var supportsVision: Bool? {
        guard let inputs = inputModalities, !inputs.isEmpty else { return nil }
        return inputs.contains("image")
    }
}
struct HeaderEntry: Identifiable, Codable, Equatable {
    var id = UUID(); var name = ""; var value = ""
}
struct Usage: Codable, Equatable {
    var input: Int?; var output: Int?; var cached: Int?; var cost: Double?
}
struct UsageRecord: Identifiable, Codable {
    var id = UUID(); var date = Date(); var chatID: UUID; var chatTitle: String
    var providerID: UUID; var providerName: String; var model: String; var usage: Usage
}
struct Chat: Identifiable, Codable, Equatable {
    var id = UUID(); var title = "Новый чат"; var model = "gpt-4o-mini"; var messages: [Message] = []
    var providerID: UUID?
    var reasoning: String?
    var webSearch: Bool?
    var archived: Bool?
    var emoji: String?
}
struct Message: Identifiable, Codable, Equatable {
    var id = UUID(); var role: String; var text: String; var attachments: [Attachment] = []
    var usage: Usage?
    var failed: Bool?
    var modelName: String?
    var thinking: String?
    var media: [GeneratedMedia]?
}
struct GeneratedMedia: Codable, Equatable, Identifiable {
    var id: String { url }
    var url: String
    var kind: String
}
struct Attachment: Identifiable, Codable, Equatable {
    var id = UUID(); var name: String; var mime: String; var data: Data
}
struct GeneratedImage: Identifiable, Codable, Equatable {
    var id = UUID()
    var prompt: String
    var model: String
    var size: String
    var data: Data
    var createdAt = Date()
}

enum ImageModelCatalog {
    static let presets = [
        "gpt-image-2.5-sunburst",
        "gpt-image-2.5-flare",
        "gpt-image-2",
        "nano-banana-2",
        "grok-imagine-image"
    ]
    static let sizes = ["1024x1024", "1024x1536", "1536x1024", "512x512"]

    private static let hints = [
        "image", "imagine", "banana", "dall-e", "flux", "stable-diffusion",
        "sdxl", "ideogram", "midjourney", "imagen"
    ]

    static func looksLikeImageModel(_ id: String) -> Bool {
        let lowered = id.lowercased()
        return hints.contains { lowered.contains($0) }
    }

    static func models(from entries: [ModelEntry]) -> [ModelEntry] {
        var result = entries.filter {
            $0.outputModalities?.contains("image") == true || looksLikeImageModel($0.id)
        }
        let existing = Set(result.map(\.id))
        for id in presets where !existing.contains(id) {
            result.append(ModelEntry(id: id, name: id, outputModalities: ["image"]))
        }
        return result
    }
}
