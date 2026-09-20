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
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            List(selection: $store.selectedChatID) {
                Section("ДИАЛОГИ") {
                    ForEach(store.chats.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }) { chat in
                        NavigationLink(value: chat.id) { Label(chat.title, systemImage: "bubble.left").font(.system(.subheadline, design: .monospaced)) }
                            .swipeActions { Button("Удалить", role: .destructive) { store.deleteChat(chat.id) }.disabled(store.isSending) }
                    }
                }
            }.searchable(text: $search, prompt: "Найти диалог")
                .scrollContentBackground(.hidden).background(Palette.background)
                .navigationTitle("klain")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Новый чат", systemImage: "square.and.pencil") { store.newChat() }.disabled(store.isSending) }
                    ToolbarItemGroup(placement: .bottomBar) { Button("Провайдеры", systemImage: "slider.horizontal.3") { settings = true }; Spacer(); Button("Статистика", systemImage: "chart.bar") { stats = true } }
                }
        } detail: {
            VStack(spacing: 0) {
                modelMenu.padding(.horizontal).padding(.vertical, 10)
                Picker("Reasoning", selection: Binding(get: { store.selectedChat?.reasoning ?? "default" }, set: { store.setReasoning($0) })) {
                    Text("Default").tag("default"); Text("Low").tag("low"); Text("Medium").tag("medium"); Text("High").tag("high"); Text("xHigh").tag("xhigh"); Text("Max").tag("max")
                }.pickerStyle(.menu).disabled(store.isSending)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if store.selectedChat?.messages.isEmpty != false { welcome }
                            ForEach(store.selectedChat?.messages ?? []) { message in MessageView(message: message).id(message.id) }
                            Color.clear.frame(height: 1).id("bottom")
                        }.padding(20)
                    }.scrollDismissesKeyboard(.interactively).gesture(DragGesture(minimumDistance: 18).onEnded { value in if value.translation.height > 30 { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }).onChange(of: store.selectedChat?.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                        .onChange(of: store.selectedChatID) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
                composer
            }.background(Palette.background).navigationTitle("klain").navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden(true)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button { compactColumn = .sidebar } label: { Label("Назад", systemImage: "chevron.left") } }; Button("Статистика", systemImage: "chart.bar") { stats = true }; Button("Провайдеры", systemImage: "slider.horizontal.3") { settings = true } }
        }
        .preferredColorScheme(.dark).tint(Palette.accent)
        .onChange(of: store.selectedChatID) { _, id in if id != nil { compactColumn = .detail } }
        .sheet(isPresented: $settings) { ProvidersView() }
        .sheet(isPresented: $stats) { StatisticsView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .movie, .pdf, .text, .data], allowsMultipleSelection: true, onCompletion: importFiles)
        .alert("Ошибка", isPresented: Binding(get: { error != nil || store.error != nil }, set: { if !$0 { error = nil; store.error = nil } })) { Button("OK") { error = nil; store.error = nil } } message: { Text(error ?? store.error ?? "") }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("✳").font(.system(size: 56)).foregroundStyle(Palette.accent)
            Text("Давай начнём.").font(.system(size: 32, weight: .medium, design: .serif))
            Text("Твои модели. Твои идеи.\nОдин спокойный уголок для диалогов.").foregroundStyle(.secondary)
            Button("Подключить провайдера", systemImage: "plus") { settings = true }.buttonStyle(.bordered)
        }.padding(.vertical, 55)
    }
    private var modelMenu: some View {
        Menu {
            ForEach(store.providers) { p in
                Section(p.name) { ForEach(p.models ?? []) { m in Button(m.name.isEmpty ? m.id : m.name) { store.select(p, model: m.id) } } }
            }
            Button("Настроить модели…") { settings = true }
        } label: {
            HStack { Circle().fill(Palette.accent).frame(width: 7, height: 7); Text(store.activeProvider?.name ?? "Подключить API"); Text(store.selectedChat?.model ?? "").foregroundStyle(.secondary).lineLimit(1); Spacer(); Image(systemName: "chevron.down") }.font(.system(.caption, design: .monospaced))
        }.disabled(store.isSending)
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !attachments.isEmpty {
                ScrollView(.horizontal) { HStack { ForEach(attachments) { a in Button { attachments.removeAll { $0.id == a.id } } label: { Label(a.name + " ×", systemImage: "paperclip").font(.caption) } } } }
            }
            TextField("Напиши что-нибудь…", text: $input, axis: .vertical).lineLimit(1...7).padding(.top, 4)
            HStack {
                Menu {
                    Button("Файлы", systemImage: "folder") { importing = true }
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) { Label("Галерея", systemImage: "photo.on.rectangle") }
                } label: { Image(systemName: "paperclip") }.onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
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
            } catch { await MainActor.run { error = error.localizedDescription } }
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
            Text(.init(message.text)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            if let u = message.usage { Text("↑ \(u.input.map(String.init) ?? "—")   ↓ \(u.output.map(String.init) ?? "—") токенов").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary) }
        }.padding(16).background(message.role == "user" ? Palette.panel : Color.clear).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
