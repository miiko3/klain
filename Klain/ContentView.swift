import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: ChatStore
    @State private var input = ""
    @State private var settings = false
    @State private var importing = false
    @State private var attachments: [Attachment] = []
    @State private var error: String?
    var body: some View {
        NavigationSplitView { List(store.chats, selection: $store.selectedChatID) { chat in Text(chat.title).tag(chat.id) }.navigationTitle("klain").toolbar { Button("+", systemImage: "square.and.pencil") { store.newChat() }.disabled(store.isSending); Button("Настройки", systemImage: "slider.horizontal.3") { settings = true } } } detail: {
            VStack(spacing: 0) {
                Text(store.selectedChat?.model ?? "Выбери модель").font(.caption).foregroundStyle(.secondary).padding(8)
                ScrollView { LazyVStack(alignment: .leading, spacing: 14) { ForEach(store.selectedChat?.messages ?? []) { m in VStack(alignment: .leading) { Text(m.role == "user" ? "Ты" : "klain").font(.caption).foregroundStyle(.secondary); ForEach(m.attachments) { a in Label(a.name, systemImage: "paperclip").font(.caption) }; Text(.init(m.text)).textSelection(.enabled) }.padding(12).background(m.role == "user" ? .blue.opacity(0.15) : .gray.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 14)).frame(maxWidth: .infinity, alignment: m.role == "user" ? .trailing : .leading) } }.padding() }
                if store.isSending { ProgressView("Ответ модели…").font(.caption) }
                ForEach(attachments) { a in HStack { Text(a.name).font(.caption); Button("Убрать") { attachments.removeAll { $0.id == a.id } } } }
                HStack { Button("Файл", systemImage: "paperclip") { importing = true }; TextField("Сообщение…", text: $input, axis: .vertical).lineLimit(1...6).textFieldStyle(.roundedBorder); Button("Отправить", systemImage: "arrow.up.circle.fill") { let x = input; let files = attachments; input = ""; attachments = []; Task { await store.send(x, attachments: files) } }.disabled(store.isSending || store.providers.isEmpty || (input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)) }.padding()
            }.navigationTitle("klain").toolbar { Button("Модели", systemImage: "slider.horizontal.3") { settings = true } }
        }
        .tint(.indigo)
        .sheet(isPresented: $settings) { SettingsView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .movie, .pdf, .text, .data], allowsMultipleSelection: true) { result in
            do { for url in try result.get() { let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0; guard size <= 20_000_000, attachments.reduce(0, { $0 + $1.data.count }) + size <= 30_000_000 else { throw NSError(domain: "File", code: 1, userInfo: [NSLocalizedDescriptionKey: "Лимит: 20 МБ на файл, 30 МБ на сообщение."]) }; attachments.append(Attachment(name: url.lastPathComponent, mime: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", data: try Data(contentsOf: url))) } } catch { self.error = error.localizedDescription }
        }
        .alert("Ошибка", isPresented: Binding(get: { error != nil || store.error != nil }, set: { if !$0 { error = nil; store.error = nil } })) { Button("OK") { error = nil; store.error = nil } } message: { Text(error ?? store.error ?? "") }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var url = "https://openrouter.ai/api/v1"
    @State private var key = ""
    @State private var models: [String] = []
    @State private var model = ""
    @State private var error = ""
    @State private var loading = false
    var body: some View {
        NavigationStack { Form {
            Section("Подключение") {
                TextField("Base URL (HTTPS)", text: $url).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("API-ключ", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Загрузить модели") { loading = true; Task { do { let p = Provider(name: "API", baseURL: url.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")), apiKey: key); models = try await APIClient().models(provider: p); error = "" } catch { self.error = error.localizedDescription }; loading = false } }.disabled(loading || key.isEmpty)
                if loading { ProgressView() }
                Text("OpenRouter, OpenAI, DeepSeek и другие OpenAI-совместимые API. Список /models не гарантирует доступ по тарифу.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Модель") { TextField("ID модели", text: $model).textInputAutocapitalization(.never).autocorrectionDisabled(); ForEach(models, id: \.self) { id in Button { model = id } label: { HStack { Text(id); if model == id { Image(systemName: "checkmark") } } } } }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            Section { Text("Вложения отправляются выбранному провайдеру вместе с историей чата. Фото требуют vision-модель. Видео и PDF реализованы для OpenRouter; поддержка зависит от модели. Ключ хранится в Keychain.").font(.caption) }
        }.navigationTitle("Модели и API").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { do { guard URL(string: url)?.scheme == "https" else { throw URLError(.badURL) }; try store.configure(name: "API", url: url, key: key); store.setModel(model); dismiss() } catch { self.error = error.localizedDescription } }.disabled(key.isEmpty || model.isEmpty || store.isSending) } }.onAppear { if let p = store.providers.first { url = p.baseURL; key = p.apiKey }; model = store.selectedChat?.model ?? "" } }
    }
}
