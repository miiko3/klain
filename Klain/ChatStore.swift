import Foundation
import Combine
import Security
import UIKit

@MainActor final class ChatStore: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var providers: [Provider] = []
    @Published var selectedChatID: UUID?
    @Published var isSending = false
    private let api = APIClient()
    @Published var error: String?
    @Published var records: [UsageRecord] = []
    @Published var remaining: [UUID: String] = [:]
    @Published var drafts: [Provider] = []
    @Published var generatedImages: [GeneratedImage] = []
    @Published var isGeneratingImage = false
    @Published var currentImagePrompt = ""
    @Published var latestImageID: UUID?
    @Published var defaultModel: String = "" {
        didSet { UserDefaults.standard.set(defaultModel, forKey: "klain.defaultModel") }
    }
    @Published var imageModel: String = "" {
        didSet { UserDefaults.standard.set(imageModel, forKey: "klain.imageModel") }
    }
    @Published var imageSize: String = "1024x1024" {
        didSet { UserDefaults.standard.set(imageSize, forKey: "klain.imageSize") }
    }
    private var generation: Task<Void, Never>?
    private var imageTask: Task<Void, Never>?
    private var activeImageRun: UUID?
    init() {
        defaultModel = UserDefaults.standard.string(forKey: "klain.defaultModel") ?? ""
        imageModel = UserDefaults.standard.string(forKey: "klain.imageModel") ?? ""
        imageSize = UserDefaults.standard.string(forKey: "klain.imageSize") ?? "1024x1024"
        load()
        loadGeneratedImages()
        do { providers = try Vault.load(); drafts = try Vault.load(account: "drafts") } catch { self.error = "Keychain: \(error.localizedDescription)" }
        if chats.isEmpty { newChat() }
        if defaultModel.isEmpty, let existing = chats.first(where: { !$0.model.isEmpty })?.model { defaultModel = existing }
    }
    func saveDraft(_ provider: Provider) { var list = drafts; if let i = list.firstIndex(where: { $0.id == provider.id }) { list[i] = provider } else { list.append(provider) }; do { try Vault.save(list, account: "drafts"); drafts = list } catch { self.error = error.localizedDescription } }
    func deleteDraft(_ id: UUID) throws { let list = drafts.filter { $0.id != id }; try Vault.save(list, account: "drafts"); drafts = list }
    func deleteDrafts(matching provider: Provider) throws {
        let list = drafts.filter { $0.id != provider.id && $0.slug != provider.slug && $0.baseURL != provider.baseURL }
        try Vault.save(list, account: "drafts"); drafts = list
    }
    func configure(_ p: Provider) throws {
        var updated = providers
        if let index = updated.firstIndex(where: { $0.id == p.id }) { updated[index] = p } else { updated.append(p) }
        try Vault.save(updated); providers = updated
    }
    func removeProvider(_ id: UUID) throws { let updated = providers.filter { $0.id != id }; try Vault.save(updated); providers = updated }
    func select(_ p: Provider, model: String) { guard !isSending, let i = chats.firstIndex(where: { $0.id == selectedChatID }) else { return }; chats[i].providerID = p.id; chats[i].model = model; defaultModel = model; save() }
    var activeProvider: Provider? { if let id = selectedChat?.providerID { return providers.first { $0.id == id } }; return providers.first }
    var selectedModelEntry: ModelEntry? {
        guard let chat = selectedChat, let provider = activeProvider else { return nil }
        return provider.models?.first { $0.id == chat.model }
    }
    func imageSupportError(for attachments: [Attachment]) -> String? {
        guard attachments.contains(where: { $0.mime.hasPrefix("image/") }) else { return nil }
        guard let entry = selectedModelEntry, let inputs = entry.inputModalities else { return nil }
        guard !inputs.contains("image") else { return nil }
        let name = entry.name.isEmpty ? entry.id : entry.name
        return "Модель \(name) не поддерживает изображения. Выбери vision-модель или убери фото."
    }
    func imageSupportWarning(for attachments: [Attachment]) -> String? {
        guard attachments.contains(where: { $0.mime.hasPrefix("image/") }) else { return nil }
        guard let entry = selectedModelEntry else { return nil }
        if let inputs = entry.inputModalities {
            return inputs.contains("image") ? nil : imageSupportError(for: attachments)
        }
        return "Поддержка изображений для модели не подтверждена. Обнови список моделей в «Провайдерах»."
    }
    func deleteChat(_ id: UUID) { guard !isSending else { return }; chats.removeAll { $0.id == id }; records.removeAll { $0.chatID == id }; if selectedChatID == id { selectedChatID = chats.first(where: { $0.archived != true })?.id }; save() }
    func archiveChat(_ id: UUID, archived: Bool) {
        guard !isSending, let i = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[i].archived = archived
        if archived, selectedChatID == id { selectedChatID = chats.first(where: { $0.archived != true })?.id }
        save()
    }
    func start(_ text: String, attachments: [Attachment]) {
        guard !isSending else { return }
        if let reason = imageSupportError(for: attachments) { error = reason; return }
        isSending = true
        generation = Task { await send(text, attachments: attachments) }
    }
    func stop() { generation?.cancel() }
    func generateImage(prompt: String, model: String, size: String, provider: Provider) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGeneratingImage, !trimmed.isEmpty, !model.isEmpty else { return }
        error = nil
        imageModel = model
        imageSize = size
        currentImagePrompt = trimmed
        latestImageID = nil
        isGeneratingImage = true
        let runID = UUID()
        activeImageRun = runID
        imageTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "klain.image")
            defer { UIApplication.shared.endBackgroundTask(backgroundTask) }
            do {
                let data = try await self.api.generateImage(provider: provider, model: model, prompt: trimmed, size: size)
                guard self.activeImageRun == runID else { return }
                let generated = GeneratedImage(prompt: trimmed, model: model, size: size, data: data)
                self.generatedImages.insert(generated, at: 0)
                self.latestImageID = generated.id
                if self.generatedImages.count > 20 {
                    self.generatedImages.removeLast(self.generatedImages.count - 20)
                }
                self.saveGeneratedImages()
            } catch {
                if !(Task.isCancelled || (error as? URLError)?.code == .cancelled),
                   self.activeImageRun == runID {
                    self.error = error.localizedDescription
                }
            }
            if self.activeImageRun == runID {
                self.activeImageRun = nil
                self.imageTask = nil
                self.isGeneratingImage = false
            }
        }
    }
    func cancelImageGeneration() {
        imageTask?.cancel()
        imageTask = nil
        activeImageRun = nil
        isGeneratingImage = false
        currentImagePrompt = ""
        latestImageID = nil
    }
    func deleteGeneratedImage(_ id: UUID) {
        generatedImages.removeAll { $0.id == id }
        saveGeneratedImages()
    }
    func setModel(_ model: String) { defaultModel = model; if let i = chats.firstIndex(where: { $0.id == selectedChatID }) { chats[i].model = model; save() } }
    func setReasoning(_ value: String) { if let i = chats.firstIndex(where: { $0.id == selectedChatID }) { chats[i].reasoning = value; save() } }
    func setWebSearch(_ enabled: Bool) { if let i = chats.firstIndex(where: { $0.id == selectedChatID }) { chats[i].webSearch = enabled; save() } }
    var selectedChat: Chat? { chats.first { $0.id == selectedChatID } }
    var activeChats: [Chat] { chats.filter { $0.archived != true } }
    var archivedChats: [Chat] { chats.filter { $0.archived == true } }
    func newChat() {
        guard !isSending else { return }
        var c = Chat()
        c.emoji = ["🌿", "🪐", "🦊", "✨", "🌊", "🍀", "🚀", "🐈", "🌻", "🦋"].randomElement()
        let provider = activeProvider
        c.providerID = provider?.id
        c.model = provider?.models?.first(where: { $0.id == defaultModel })?.id
            ?? selectedChat?.model
            ?? provider?.models?.first?.id
            ?? ""
        chats.insert(c, at: 0)
        selectedChatID = c.id
        save()
    }
    func send(_ text: String, attachments: [Attachment] = []) async {
        defer { isSending = false; generation = nil; save() }
        guard let index = chats.firstIndex(where: { $0.id == selectedChatID }), let provider = activeProvider, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty else { return }
        chats[index].messages.append(Message(role: "user", text: text, attachments: attachments))
        if chats[index].messages.count == 1 { chats[index].title = String((text.isEmpty ? attachments.first?.name ?? "Вложение" : text).prefix(40)) }; let assistant = Message(role: "assistant", text: "")
        chats[index].messages.append(assistant); isSending = true; save()
        chats[index].messages[chats[index].messages.count - 1].modelName = provider.models?.first(where: { $0.id == chats[index].model })?.name ?? chats[index].model
        var requestChat = chats[index]; requestChat.messages.removeLast()
        let messageIndex = chats[index].messages.count - 1
        var reported: Usage?
        do {
            for try await event in api.stream(chat: requestChat, provider: provider) {
                switch event {
                case .thinking(let text): chats[index].messages[messageIndex].thinking = (chats[index].messages[messageIndex].thinking ?? "") + text
                case .media(let media):
                    if chats[index].messages[messageIndex].media == nil { chats[index].messages[messageIndex].media = [] }
                    if chats[index].messages[messageIndex].media?.contains(media) != true { chats[index].messages[messageIndex].media?.append(media) }
                case .text(let text): chats[index].messages[messageIndex].text += text
                case .usage(let usage): reported = usage; chats[index].messages[messageIndex].usage = usage
                case .remaining(let value): remaining[provider.id] = value + "\nОбновлено: \(Date().formatted())"
                }
            }
        } catch {
            chats[index].messages[messageIndex].failed = true
            chats[index].messages[messageIndex].text += Task.isCancelled ? "\n[Остановлено]" : "\nОшибка: \(friendlyError(error))"
        }
        if let usage = reported { records.append(UsageRecord(chatID: requestChat.id, chatTitle: requestChat.title, providerID: provider.id, providerName: provider.name, model: requestChat.model, usage: usage)) }
    }
    private func friendlyError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost:
                return "Соединение с провайдером оборвалось. Возможно, модель не поддерживает изображение или файл слишком большой. Попробуй JPG/PNG меньшего размера."
            case .timedOut:
                return "Провайдер не ответил вовремя. Попробуй ещё раз."
            case .notConnectedToInternet:
                return "Нет подключения к интернету."
            case .cancelled:
                return "Запрос отменён."
            default:
                break
            }
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("network connection was lost") {
            return "Соединение с провайдером оборвалось. Возможно, модель не поддерживает изображение или файл слишком большой. Попробуй JPG/PNG меньшего размера."
        }
        if text.localizedCaseInsensitiveContains("could not read an image") {
            return "Провайдер не смог прочитать изображение. Модель может не поддерживать картинки либо формат не JPG/PNG."
        }
        return text
    }
    private var file: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("chats.json") }
    private var usageFile: URL { file.deletingLastPathComponent().appendingPathComponent("usage.json") }
    private var imagesFile: URL { file.deletingLastPathComponent().appendingPathComponent("images.json") }
    private func saveGeneratedImages() {
        do {
            try JSONEncoder().encode(generatedImages).write(to: imagesFile, options: [.atomic, .completeFileProtection])
        } catch {
            self.error = error.localizedDescription
        }
    }
    private func loadGeneratedImages() {
        guard let data = try? Data(contentsOf: imagesFile),
              let decoded = try? JSONDecoder().decode([GeneratedImage].self, from: data) else { return }
        generatedImages = decoded
    }
    private func save() { do { try JSONEncoder().encode(chats).write(to: file, options: [.atomic, .completeFileProtection]); try JSONEncoder().encode(records).write(to: usageFile, options: [.atomic, .completeFileProtection]) } catch { self.error = error.localizedDescription } }
    private func load() {
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                chats = try JSONDecoder().decode([Chat].self, from: Data(contentsOf: file))
                selectedChatID = chats.first(where: { $0.archived != true })?.id ?? chats.first?.id
            }
            if FileManager.default.fileExists(atPath: usageFile.path) {
                records = try JSONDecoder().decode([UsageRecord].self, from: Data(contentsOf: usageFile))
            }
        } catch { self.error = "Не удалось прочитать историю: \(error.localizedDescription)" }
    }
}

enum Vault {
    static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "klain.providers", kSecAttrAccount as String: "default"] }
    static func save(_ providers: [Provider], account: String = "default") throws {
        var query = self.query; query[kSecAttrAccount as String] = account
        let data = try JSONEncoder().encode(providers)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound { var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly; let result = SecItemAdd(q as CFDictionary, nil); guard result == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result)) } }
        else if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    static func load(account: String = "default") throws -> [Provider] { var q = query; q[kSecAttrAccount as String] = account; q[kSecReturnData as String] = true; var result: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary, &result); if status == errSecItemNotFound { return [] }; guard status == errSecSuccess, let data = result as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }; return try JSONDecoder().decode([Provider].self, from: data) }
}
