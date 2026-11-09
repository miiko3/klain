import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import UIKit

enum Palette {
    static let background = Color.primary.opacity(0.04)
    static let panel = Color.primary.opacity(0.06)
    static let accent = Color.primary
}

private struct ChatBottomPrefKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

enum Route: Hashable {
    case chats, images, settings, chat(UUID)
}

struct ContentView: View {
    @EnvironmentObject var store: ChatStore
    @State private var input = ""
    @State private var followTail = true
    @State private var settings = false
    @State private var stats = false
    @State private var importing = false
    @State private var attachments: [Attachment] = []
    @State private var error: String?
    @State private var photoItems: [PhotosPickerItem] = []
    @SceneStorage("klain.nav") private var storedPath = ""
    @State private var path: [Route] = []
    @State private var deleting: UUID?
    @State private var gallery = false
    @State private var camera = false
    var body: some View {
        NavigationStack(path: $path) {
            home
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .chats: chatsList
                    case .images: ImageStudioView()
                    case .settings: settingsList
                    case .chat(let id): chatDetail.onAppear { store.selectedChatID = id }
                    }
                }
        }
        .tint(Color.primary)
        .confirmationDialog("Удалить чат?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Удалить навсегда", role: .destructive) { if let id = deleting { store.deleteChat(id) }; deleting = nil }
            Button("Отмена", role: .cancel) { deleting = nil }
        } message: { Text("Все локальные данные чата, вложения и его статистика будут стёрты. Восстановить их нельзя. Данные у API-провайдера это не удаляет.") }
        .sheet(isPresented: $settings) { ProvidersView() }
        .sheet(isPresented: $stats) { StatisticsView() }
        .photosPicker(isPresented: $gallery, selection: $photoItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos, .livePhotos]))
        .onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
        .sheet(isPresented: $camera) { CameraCapture { data in
            guard let attachment = ImageTools.attachment(name: "Фото.jpg", data: data) else {
                error = "Не удалось обработать фото"
                return
            }
            guard attachment.data.count <= 20_000_000,
                  attachments.reduce(0, { $0 + $1.data.count }) + attachment.data.count <= 30_000_000 else {
                error = "Лимит вложений: 30 МБ"
                return
            }
            attachments.append(attachment)
        } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .movie, .pdf, .text, .data], allowsMultipleSelection: true, onCompletion: importFiles)
        .alert("Ошибка", isPresented: Binding(get: { error != nil || store.error != nil }, set: { if !$0 { error = nil; store.error = nil } })) { Button("OK") { error = nil; store.error = nil } } message: { Text(error ?? store.error ?? "") }
        .onAppear(perform: restorePath)
        .onChange(of: path) { _, value in storedPath = encode(value) }
    }
    private func encode(_ routes: [Route]) -> String {
        routes.map { route in
            switch route {
            case .chat(let id): return "chat:\(id.uuidString)"
            case .chats: return "chats"
            case .images: return "images"
            case .settings: return "settings"
            }
        }.joined(separator: "|")
    }
    private func restorePath() {
        guard path.isEmpty, !storedPath.isEmpty else { return }
        let restored: [Route] = storedPath.split(separator: "|").compactMap { part in
            if part.hasPrefix("chat:"), let id = UUID(uuidString: String(part.dropFirst(5))) {
                guard store.chats.contains(where: { $0.id == id }) else { return nil }
                return .chat(id)
            }
            switch part {
            case "chats": return .chats
            case "images": return .images
            case "settings": return .settings
            default: return nil
            }
        }
        guard !restored.isEmpty else { return }
        path = restored
        if case .chat(let id) = restored.last {
            store.selectedChatID = id
        }
    }
    private var home: some View {
        ZStack {
            LiquidBackground()
            ScrollView {
                VStack(spacing: 14 * AppScale.k) {
                    // Native large title comes from .navigationTitle below;
                    // here we only place the brand mark on the trailing side.
                    HStack {
                        Spacer()
                        Image("BrandLogo")
                            .resizable().scaledToFit()
                            .frame(width: 40 * AppScale.k, height: 40 * AppScale.k)
                            .clipShape(RoundedRectangle(cornerRadius: 10 * AppScale.k, style: .continuous))
                    }
                    .padding(.bottom, 4 * AppScale.k)
                    HomeBanner()
                    SigningReminder()
                }
                .padding(.horizontal, 16 * AppScale.k)
                .padding(.top, 8 * AppScale.k)
                .padding(.bottom, 140 * AppScale.k)
            }
        }
        .glassContainer()
        .navigationTitle("klain")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) { homeMenu }
    }
    private var homeMenu: some View {
        HStack(spacing: 0) {
            menuButton("Чаты", icon: "bubble.left.and.bubble.right", action: { path.append(.chats) })
            menuButton("Картинки", icon: "sparkles", action: { path.append(.images) })
            menuButton("Настройки", icon: "slider.horizontal.3", action: { path.append(.settings) })
        }
        .padding(.horizontal, 6 * AppScale.k)
        .padding(.vertical, 10 * AppScale.k)
        // Floating system-glass bar (Telegram / iOS 26 style).
        .glassCapsule()
        .padding(.horizontal, 16 * AppScale.k)
        .padding(.bottom, 22 * AppScale.k)
    }
    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5 * AppScale.k) {
                Image(systemName: icon)
                    .font(.system(size: 22 * AppScale.k, weight: .light))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 12 * AppScale.k, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4 * AppScale.k)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    private var chatsList: some View {
        ZStack {
            LiquidBackground()
            List {
                if store.activeChats.isEmpty && store.archivedChats.isEmpty {
                    Section { emptyChats.listRowBackground(Color.clear).listRowSeparator(.hidden) }
                } else {
                    if !store.activeChats.isEmpty {
                        Section("ДИАЛОГИ") { chatRows(store.activeChats, archived: false) }
                    }
                    if !store.archivedChats.isEmpty {
                        Section("АРХИВЫ") { chatRows(store.archivedChats, archived: true) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .glassContainer()
        .navigationTitle("Чаты")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.activeChats.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.newChat(); if let id = store.selectedChatID { path.append(.chat(id)) } } label: { Label("Новый чат", systemImage: "square.and.pencil") }.disabled(store.isSending)
                }
            }
        }
    }
    private func chatRows(_ chats: [Chat], archived: Bool) -> some View {
        ForEach(chats) { chat in
            NavigationLink(value: Route.chat(chat.id)) {
                HStack(spacing: 12) {
                    Text(chat.emoji ?? "💬").font(.system(size: 24 * AppScale.k))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(chat.title).font(.system(.subheadline, design: .rounded).weight(.semibold)).lineLimit(1)
                        Text(chat.model).font(.system(size: 10 * AppScale.k, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11 * AppScale.k, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .padding(14 * AppScale.k)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .swipeActions(allowsFullSwipe: false) {
                Button("Удалить", role: .destructive) { deleting = chat.id }.disabled(store.isSending)
                Button(archived ? "Вернуть" : "В архив") { store.archiveChat(chat.id, archived: !archived) }.disabled(store.isSending)
            }
        }
    }
    private var emptyChats: some View {
        VStack(spacing: 14) {
            Text("🪄").font(.system(size: 54 * AppScale.k))
            Text("Чатов пока нет,\nно творить волшебство можно начать в любой момент").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { store.newChat(); if let id = store.selectedChatID { path.append(.chat(id)) } } label: { Label("Новый чат", systemImage: "square.and.pencil") }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .disabled(store.isSending)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30 * AppScale.k)
        .padding(.horizontal, 18 * AppScale.k)
    }
    private var settingsList: some View {
        SettingsScreen(openImages: { path.append(.images) })
    }
    private var chatDetail: some View {
        ZStack {
            LiquidBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            if store.selectedChat?.messages.isEmpty != false { welcome }
                            ForEach(store.selectedChat?.messages ?? []) { message in
                                MessageView(message: message, waiting: store.isSending && message.id == store.selectedChat?.messages.last?.id)
                                    .id(message.id)
                            }
                            Color.clear.frame(height: 1 * AppScale.k).id("bottom")
                        }
                        .padding(.horizontal, 18 * AppScale.k)
                        .padding(.top, 12 * AppScale.k)
                        .padding(.bottom, 14 * AppScale.k)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ChatBottomPrefKey.self,
                                value: geo.frame(in: .named("chatScroll")).maxY)
                        })
                    }
                    .coordinateSpace(name: "chatScroll")
                    .scrollDismissesKeyboard(.interactively)
                    // Follow the stream ONLY while the user is pinned to the bottom.
                    // A manual scroll-up disables auto-follow so the chat no longer
                    // yanks back on every token.
                    .onPreferenceChange(ChatBottomPrefKey.self) { _ in
                        if followTail, store.isSending {
                            DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo("bottom", anchor: .bottom) } }
                        }
                    }
                    .simultaneousGesture(DragGesture().onChanged { _ in followTail = false })
                    .onChange(of: store.selectedChatID) { _, _ in followTail = true; proxy.scrollTo("bottom", anchor: .bottom) }
                    .safeAreaInset(edge: .bottom) {
                        if !followTail {
                            Button { followTail = true; withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } label: {
                                Label("К последнему сообщению", systemImage: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 14 * AppScale.k)
                                    .padding(.vertical, 9 * AppScale.k)
                            }.padding(.bottom, 6 * AppScale.k)
                        }
                    }
                }
                composer
            }
        }
        .glassContainer()
        .navigationTitle(store.selectedChat?.title ?? "Новый чат")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { stats = true } label: {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 17 * AppScale.k, weight: .regular))
                        .foregroundStyle(.primary)
                }.accessibilityLabel("Статистика")
                Button { settings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17 * AppScale.k, weight: .regular))
                        .foregroundStyle(.primary)
                }.accessibilityLabel("Провайдеры")
            }
        }
    }
    private var welcome: some View {
        VStack(alignment: .center, spacing: 16) {
            ZStack {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120 * AppScale.k, height: 120 * AppScale.k)

                Text(store.selectedChat?.emoji ?? "✨")
                    .font(.system(size: 26 * AppScale.k))
                    .offset(y: -46)
                    .padding(6 * AppScale.k)
            }
            Text("Давай начнём.").font(.system(size: 30 * AppScale.k, weight: .bold, design: .rounded))
            Text("Твои модели. Твои идеи.\nОдин спокойный уголок для диалогов.").foregroundStyle(.secondary)
            if store.providers.isEmpty { Button("Подключить провайдера", systemImage: "plus") { settings = true }.buttonStyle(GlassButtonStyle()) }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
        .padding(24 * AppScale.k)
    }
    private var modelMenu: some View {
        Menu {
            ForEach(store.providers) { p in
                Section(p.name) {
                    ForEach(p.models ?? []) { m in
                        Button { store.select(p, model: m.id) } label: {
                            if m.supportsVision == true {
                                Label(m.name.isEmpty ? m.id : m.name, systemImage: "camera.viewfinder")
                            } else {
                                Text(m.name.isEmpty ? m.id : m.name)
                            }
                        }
                    }
                }
            }
            Button("Настроить модели…") { settings = true }
        } label: {
            HStack(spacing: 6) {
                if store.selectedModelEntry?.supportsVision == true {
                    Image(systemName: "camera.viewfinder").font(.caption2)
                }
                Text(store.selectedChat?.model ?? "Выбрать модель").lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4 * AppScale.k)
            .padding(.vertical, 6 * AppScale.k)
        }
        .disabled(store.isSending)
    }
    // Reasoning + web controls now live INSIDE the composer, above the text field.
    private var chatControls: some View {
        HStack(spacing: 8 * AppScale.k) {
            modelMenu
            Menu {
                ForEach(["default", "low", "medium", "high", "xhigh", "max"], id: \.self) { level in
                    Button { store.setReasoning(level) } label: { Label(level == "xhigh" ? "xHigh" : level.capitalized, systemImage: store.selectedChat?.reasoning == level ? "checkmark" : "brain") }
                }
            } label: {
                Label((store.selectedChat?.reasoning ?? "default").capitalized, systemImage: "brain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4 * AppScale.k)
                    .padding(.vertical, 6 * AppScale.k)
            }.disabled(store.isSending)
            Button {
                store.setWebSearch(store.selectedChat?.webSearch != true)
            } label: {
                Label("Сеть", systemImage: "globe")
                    .font(.caption)
                    .padding(10 * AppScale.k)
                    .foregroundStyle(.primary)
            }
                .disabled(store.isSending).help("Веб-поиск выполняет провайдер")
        }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            chatControls
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { a in
                            AttachmentThumb(attachment: a) {
                                attachments.removeAll { $0.id == a.id }
                            }
                        }
                    }
                    .padding(.horizontal, 2 * AppScale.k)
                }
            }
            TextField("Напиши что-нибудь…", text: $input, axis: .vertical).lineLimit(1...7)
                .foregroundStyle(.primary).tint(.primary)
                .padding(.horizontal, 16 * AppScale.k)
                .padding(.vertical, 11 * AppScale.k)
                // Floating glass input field (Telegram / iOS 26 style).
                .glassCapsule()
            if let reason = store.imageSupportWarning(for: attachments) {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8 * AppScale.k) {
                Menu {
                    Button("Файлы", systemImage: "folder") { importing = true }
                    Button("Галерея", systemImage: "photo.on.rectangle") { gallery = true }
                    Button("Камера", systemImage: "camera") {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { camera = true } else { error = "Камера недоступна" }
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 17 * AppScale.k, weight: .light))
                        .foregroundStyle(.primary)
                        .frame(width: 40 * AppScale.k, height: 40 * AppScale.k)
                        .glassCircle()
                }
                Spacer()
                if store.isSending {
                    Button { store.stop() } label: {
                        Image(systemName: "stop")
                            .font(.system(size: 14 * AppScale.k, weight: .regular))
                            .foregroundStyle(.primary)
                            .frame(width: 40 * AppScale.k, height: 40 * AppScale.k)
                            .glassCircle()
                    }
                } else {
                    Button {
                        if let reason = store.imageSupportError(for: attachments) {
                            error = reason
                            return
                        }
                        let text = input
                        let files = attachments
                        input = ""
                        attachments = []
                        store.start(text, attachments: files)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16 * AppScale.k, weight: .regular))
                            .foregroundStyle(Color.primary)
                            .frame(width: 40 * AppScale.k, height: 40 * AppScale.k)
                            .glassCircle()
                    }
                    .disabled(
                        store.activeProvider == nil
                            || store.selectedChat?.model.isEmpty != false
                            || (input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)
                            || store.imageSupportError(for: attachments) != nil
                    )
                }
            }
        }
        .padding(.horizontal, 16 * AppScale.k)
        .padding(.bottom, 10 * AppScale.k)
        .padding(.top, 4 * AppScale.k)
    }
    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            var imported: [Attachment] = []
            var total = attachments.reduce(0) { $0 + $1.data.count }
            for url in try result.get() {
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 20_000_000, total + size <= 30_000_000 else { throw NSError(domain: "File", code: 1, userInfo: [NSLocalizedDescriptionKey: "Лимит: 20 МБ на файл, 30 МБ на сообщение."]) }
                let data = try Data(contentsOf: url)
                let type = UTType(filenameExtension: url.pathExtension)
                if ImageTools.isImageType(type) {
                    guard let attachment = ImageTools.attachment(name: url.deletingPathExtension().lastPathComponent + ".jpg", data: data) else {
                        throw NSError(domain: "File", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось обработать изображение \(url.lastPathComponent)."])
                    }
                    total += attachment.data.count
                    imported.append(attachment)
                } else {
                    total += data.count
                    imported.append(Attachment(name: url.lastPathComponent, mime: type?.preferredMIMEType ?? "application/octet-stream", data: data))
                }
            }
            attachments.append(contentsOf: imported)
        } catch { self.error = error.localizedDescription }
    }
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var imported: [Attachment] = []
        var total = attachments.reduce(0) { $0 + $1.data.count }
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw URLError(.cannotDecodeContentData) }
                guard data.count <= 20_000_000 else { throw NSError(domain: "File", code: 1, userInfo: [NSLocalizedDescriptionKey: "Лимит: 20 МБ на файл, 30 МБ на сообщение."]) }
                let contentType = item.supportedContentTypes.first
                let attachment: Attachment
                if contentType?.conforms(to: .image) == true {
                    guard let image = ImageTools.attachment(name: "Фото \(attachments.count + imported.count + 1).jpg", data: data) else {
                        throw NSError(domain: "File", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось обработать изображение."])
                    }
                    attachment = image
                } else {
                    let mime = contentType?.preferredMIMEType ?? "application/octet-stream"
                    attachment = Attachment(name: "Медиа \(attachments.count + imported.count + 1)", mime: mime, data: data)
                }
                guard total + attachment.data.count <= 30_000_000 else {
                    throw NSError(domain: "File", code: 1, userInfo: [NSLocalizedDescriptionKey: "Лимит: 20 МБ на файл, 30 МБ на сообщение."])
                }
                total += attachment.data.count
                imported.append(attachment)
            } catch { await MainActor.run { self.error = error.localizedDescription } }
        }
        await MainActor.run {
            attachments.append(contentsOf: imported)
            photoItems = []
        }
    }
}

struct AttachmentThumb: View {
    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if attachment.mime.hasPrefix("image/"),
               let image = UIImage(data: attachment.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58 * AppScale.k, height: 58 * AppScale.k)
                    .clipShape(RoundedRectangle(cornerRadius: 14 * AppScale.k, style: .continuous))
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 22 * AppScale.k, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(width: 58 * AppScale.k, height: 58 * AppScale.k)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8 * AppScale.k, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 18 * AppScale.k, height: 18 * AppScale.k)
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
        .padding(.top, 5 * AppScale.k)
        .padding(.trailing, 5 * AppScale.k)
    }
}

struct MessageView: View {
    let message: Message
    var waiting = false

    private var isUser: Bool { message.role == "user" }

    private var images: [Attachment] {
        message.attachments.filter { $0.mime.hasPrefix("image/") }
    }

    private var files: [Attachment] {
        message.attachments.filter { !$0.mime.hasPrefix("image/") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                isUser ? "ТЫ" : (message.modelName ?? "Модель"),
                systemImage: isUser ? "person" : "sparkle"
            )
            .font(.system(size: 10 * AppScale.k, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)

            if message.role == "assistant" && (waiting || message.thinking != nil) {
                DisclosureGroup {
                    Text(message.thinking ?? "Провайдер не передаёт текст рассуждений.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } label: {
                    HStack {
                        if waiting && message.text.isEmpty { TypingDots() }
                        Text(waiting && message.text.isEmpty ? "Думает…" : "Мышление")
                            .font(.caption)
                    }
                }
            }

            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images) { a in
                            if let image = UIImage(data: a.data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 108 * AppScale.k, height: 108 * AppScale.k)
                                    .clipShape(RoundedRectangle(cornerRadius: 16 * AppScale.k, style: .continuous))
                            }
                        }
                    }
                }
            }

            ForEach(files) { a in
                Label(a.name, systemImage: "doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            MarkdownMessage(text: message.text)

            ForEach(message.media ?? []) { media in GeneratedMediaView(media: media) }

            if let u = message.usage {
                Text("↑ \(u.input.map(String.init) ?? "—")   ↓ \(u.output.map(String.init) ?? "—") токенов")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6 * AppScale.k)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
