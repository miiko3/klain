import Foundation

struct Provider: Identifiable, Codable, Equatable {
    var id = UUID(); var name: String; var baseURL: String; var apiKey: String
}
struct Chat: Identifiable, Codable, Equatable {
    var id = UUID(); var title = "Новый чат"; var model = "gpt-4o-mini"; var messages: [Message] = []
}
struct Message: Identifiable, Codable, Equatable {
    var id = UUID(); var role: String; var text: String; var attachments: [Attachment] = []
}
struct Attachment: Identifiable, Codable, Equatable {
    var id = UUID(); var name: String; var mime: String; var data: Data
}
