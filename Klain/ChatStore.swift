import Foundation
import Combine
import Security

@MainActor final class ChatStore: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var providers: [Provider] = []
    @Published var selectedChatID: UUID?
    @Published var isSending = false
    private let api = APIClient()
    @Published var error: String?
    init() { load(); providers = (try? Vault.load()) ?? []; if chats.isEmpty { newChat() } }
    func configure(name: String, url: String, key: String) throws {
        let p = Provider(name: name, baseURL: url.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")), apiKey: key)
        try Vault.save([p]); providers = [p]
    }
    func setModel(_ model: String) { if let i = chats.firstIndex(where: { $0.id == selectedChatID }) { chats[i].model = model; save() } }
    var selectedChat: Chat? { chats.first { $0.id == selectedChatID } }
    func newChat() { let c = Chat(); chats.insert(c, at: 0); selectedChatID = c.id; save() }
    func send(_ text: String, attachments: [Attachment] = []) async {
        guard !isSending, let index = chats.firstIndex(where: { $0.id == selectedChatID }), !providers.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty else { return }
        chats[index].messages.append(Message(role: "user", text: text, attachments: attachments))
        chats[index].title = String(text.prefix(32)); let assistant = Message(role: "assistant", text: "")
        chats[index].messages.append(assistant); isSending = true; save()
        var requestChat = chats[index]; requestChat.messages.removeLast()
        do { for try await part in api.stream(chat: requestChat, provider: providers.first) { chats[index].messages[chats[index].messages.count - 1].text += part } }
        catch { chats[index].messages[chats[index].messages.count - 1].text = "Ошибка: \(error.localizedDescription)" }
        isSending = false; save()
    }
    private var file: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("chats.json") }
    private func save() { do { try JSONEncoder().encode(chats).write(to: file, options: [.atomic, .completeFileProtection]) } catch { self.error = error.localizedDescription } }
    private func load() { if let d = try? Data(contentsOf: file), let c = try? JSONDecoder().decode([Chat].self, from: d) { chats = c; selectedChatID = c.first?.id } }
}

enum Vault {
    static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "klain.providers", kSecAttrAccount as String: "default"] }
    static func save(_ providers: [Provider]) throws {
        let data = try JSONEncoder().encode(providers)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound { var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly; let result = SecItemAdd(q as CFDictionary, nil); guard result == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result)) } }
        else if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    static func load() throws -> [Provider] { var q = query; q[kSecReturnData as String] = true; var result: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary, &result); if status == errSecItemNotFound { return [] }; guard status == errSecSuccess, let data = result as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }; return try JSONDecoder().decode([Provider].self, from: data) }
}
