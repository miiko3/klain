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
