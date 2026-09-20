import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

enum Palette {
    static let background = Color(red: 0.09, green: 0.09, blue: 0.085)
    static let panel = Color(red: 0.14, green: 0.14, blue: 0.13)
    static let accent = Color(red: 0.82, green: 0.48, blue: 0.35)
}

struct ContentView: View {
    @EnvironmentObject var store: ChatStore
    @State private var input = ""
    @State private var settings = false
    @State private var stats = false
    @State private var importing = false
    @State private var attachments: [Attachment] = []
    @State private var error: String?
    @State private var search = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var path: [UUID] = []
    @State private var showArchive = false
    @State private var deleting: UUID?
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section { HomeBanner() }
                Section { SigningReminder() }
                Picker("Чаты", selection: $showArchive) { Text("Диалоги").tag(false); Text("Архив").tag(true) }.pickerStyle(.segmented)
                Section("ДИАЛОГИ") {
                    ForEach(store.chats.filter { ($0.archived == true) == showArchive && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) }) { chat in
                        NavigationLink(value: chat.id) { Text("\(chat.emoji ?? "💬") \(chat.title)").font(.system(.subheadline, design: .monospaced)) }
                            .swipeActions(allowsFullSwipe: false) {
                                Button("Удалить", role: .destructive) { deleting = chat.id }.disabled(store.isSending)
                                Button(showArchive ? "Вернуть" : "В архив") { store.archiveChat(chat.id, archived: !showArchive) }.tint(.orange).disabled(store.isSending)
                            }
                    }
                }
            }.searchable(text: $search, prompt: "Найти диалог")
                .scrollContentBackground(.hidden).background(Palette.background)
                .navigationTitle("klain")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Новый чат", systemImage: "square.and.pencil") { store.newChat(); if let id = store.selectedChatID { path = [id] } }.disabled(store.isSending) }
                ToolbarItemGroup(placement: .bottomBar) { Button("Провайдеры", systemImage: "slider.horizontal.3") { settings = true }; Spacer(); Button("Статистика", systemImage: "chart.bar") { stats = true } }
                }
                .navigationDestination(for: UUID.self) { id in
                    chatDetail.onAppear { store.selectedChatID = id }
                }
        }
        .preferredColorScheme(.dark).tint(Palette.accent)
        .confirmationDialog("Удалить чат?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Удалить навсегда", role: .destructive) { if let id = deleting { store.deleteChat(id) }; deleting = nil }
            Button("Отмена", role: .cancel) { deleting = nil }
        } message: { Text("Все локальные данные чата, вложения и его статистика будут стёрты. Восстановить их нельзя. Данные у API-провайдера это не удаляет.") }
        .sheet(isPresented: $settings) { ProvidersView() }
        .sheet(isPresented: $stats) { StatisticsView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .movie, .pdf, .text, .data], allowsMultipleSelection: true, onCompletion: importFiles)
        .alert("Ошибка", isPresented: Binding(get: { error != nil || store.error != nil }, set: { if !$0 { error = nil; store.error = nil } })) { Button("OK") { error = nil; store.error = nil } } message: { Text(error ?? store.error ?? "") }
    }
    private var chatDetail: some View {
            VStack(spacing: 0) {
                HStack {
                    modelMenu
                    Menu {
                        ForEach(["default", "low", "medium", "high", "xhigh", "max"], id: \.self) { level in
                            Button { store.setReasoning(level) } label: { Label(level == "xhigh" ? "xHigh" : level.capitalized, systemImage: store.selectedChat?.reasoning == level ? "checkmark" : "brain") }
                        }
                    } label: { Label((store.selectedChat?.reasoning ?? "default").capitalized, systemImage: "brain").font(.caption).padding(10).background(Palette.panel).clipShape(Capsule()) }.disabled(store.isSending)
                }.padding(.horizontal).padding(.vertical, 10)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if store.selectedChat?.messages.isEmpty != false { welcome }
                            ForEach(store.selectedChat?.messages ?? []) { message in MessageView(message: message).id(message.id) }
                            if store.isSending && store.selectedChat?.messages.last?.text.isEmpty == true {
                                HStack(spacing: 10) { ProgressView(); Text("Думает…").foregroundStyle(.secondary) }
                                    .padding(.horizontal, 16).accessibilityElement(children: .combine)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }.padding(20)
                    }.scrollDismissesKeyboard(.interactively).onChange(of: store.selectedChat?.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                        .onChange(of: store.selectedChatID) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
                composer
            }.background(Palette.background).navigationTitle(store.selectedChat?.title ?? "Новый чат").navigationBarTitleDisplayMode(.inline)
                .background(BackTitleConfigurator())
                .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button("Статистика", systemImage: "chart.bar") { stats = true }; Button("Провайдеры", systemImage: "slider.horizontal.3") { settings = true } } }
    }
    private var welcome: some View {
        VStack(alignment: .center, spacing: 18) {
            Text(store.selectedChat?.emoji ?? "✨").font(.system(size: 56))
            Text("Давай начнём.").font(.system(size: 32, weight: .medium, design: .serif))
            Text("Твои модели. Твои идеи.\nОдин спокойный уголок для диалогов.").foregroundStyle(.secondary)
            if store.providers.isEmpty { Button("Подключить провайдера", systemImage: "plus") { settings = true }.buttonStyle(.bordered) }
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 300, alignment: .center).padding(.vertical, 24)
    }
    private var modelMenu: some View {
        Menu {
            ForEach(store.providers) { p in
                Section(p.name) { ForEach(p.models ?? []) { m in Button(m.name.isEmpty ? m.id : m.name) { store.select(p, model: m.id) } } }
            }
            Button("Настроить модели…") { settings = true }
        } label: {
            HStack { Text(store.selectedChat?.model ?? "Выбрать модель").lineLimit(1); Spacer(); Image(systemName: "chevron.down") }.font(.system(.caption, design: .monospaced)).padding(10).background(Palette.panel).clipShape(Capsule())
        }.disabled(store.isSending)
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !attachments.isEmpty {
                ScrollView(.horizontal) { HStack { ForEach(attachments) { a in Button { attachments.removeAll { $0.id == a.id } } label: { Label(a.name + " ×", systemImage: "paperclip").font(.caption) } } } }
            }
            TextField("Напиши что-нибудь…", text: $input, axis: .vertical).lineLimit(1...7).padding(.top, 4)
            HStack {
                Button("Файлы", systemImage: "folder") { importing = true }.labelStyle(.iconOnly)
                PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) { Image(systemName: "photo.on.rectangle") }.onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
                Text("klain / chat").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                if store.isSending { Button("Стоп", systemImage: "stop.circle.fill") { store.stop() } }
                else { Button { let text = input; let files = attachments; input = ""; attachments = []; store.start(text, attachments: files) } label: { Image(systemName: "arrow.up").fontWeight(.bold).padding(9).background(Palette.accent).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 8)) }.disabled(store.activeProvider == nil || store.selectedChat?.model.isEmpty != false || (input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)) }
            }
        }.padding(14).background(Palette.panel).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12))).padding(12)
    }
    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get() {
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 20_000_000, attachments.reduce(0, { $0 + $1.data.count }) + size <= 30_000_000 else { throw NSError(domain: "File", code: 1, userInfo: [NSLocalizedDescriptionKey: "Лимит: 20 МБ на файл, 30 МБ на сообщение."]) }
                attachments.append(Attachment(name: url.lastPathComponent, mime: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", data: try Data(contentsOf: url)))
            }
        } catch { self.error = error.localizedDescription }
    }
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw URLError(.cannotDecodeContentData) }
                guard data.count <= 20_000_000, attachments.reduce(0, { $0 + $1.data.count }) + data.count <= 30_000_000 else { throw NSError(domain: "File", code: 1, userInfo: [NSLocalizedDescriptionKey: "Лимит: 20 МБ на файл, 30 МБ на сообщение."]) }
                let type = item.supportedContentTypes.first?.preferredMIMEType ?? "application/octet-stream"
                await MainActor.run { attachments.append(Attachment(name: "Медиа \(attachments.count + 1)", mime: type, data: data)) }
            } catch { await MainActor.run { self.error = error.localizedDescription } }
        }
        await MainActor.run { photoItems = [] }
    }
}

struct MessageView: View {
    let message: Message
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message.role == "user" ? "ТЫ" : "KLAIN", systemImage: message.role == "user" ? "person.crop.circle" : "sparkle").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.accent)
            ForEach(message.attachments) { a in Label(a.name, systemImage: "doc").font(.caption).foregroundStyle(.secondary) }
            MarkdownMessage(text: message.text)
            ForEach(message.media ?? []) { media in GeneratedMediaView(media: media) }
            if let u = message.usage { Text("↑ \(u.input.map(String.init) ?? "—")   ↓ \(u.output.map(String.init) ?? "—") токенов").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary) }
        }.padding(16).background(message.role == "user" ? Palette.panel : Color.clear).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
