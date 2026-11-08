import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import UIKit

enum Palette {
    static let background = Color(red: 0.09, green: 0.09, blue: 0.085)
    static let panel = Color(red: 0.14, green: 0.14, blue: 0.13)
    static let accent = Color(red: 0.82, green: 0.48, blue: 0.35)
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
        .preferredColorScheme(.dark).tint(GlassPalette.accent)
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
                VStack(spacing: 14) {
                    HomeBanner()
                    SigningReminder()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 140)
            }
        }
        .navigationTitle("klain")
        .safeAreaInset(edge: .bottom) { homeMenu }
    }
    private var homeMenu: some View {
        HStack(spacing: 6) {
            menuButton("Чаты", icon: "bubble.left.and.bubble.right.fill", tint: GlassPalette.accent, action: { path.append(.chats) })
            menuButton("Картинки", icon: "sparkles", tint: GlassPalette.accent2, action: { path.append(.images) })
            menuButton("Настройки", icon: "slider.horizontal.3", tint: GlassPalette.cyan, action: { path.append(.settings) })
        }
        .padding(7)
        .glassSurface(radius: 30)
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
    }
    private func menuButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(tint.opacity(0.20)))
                    )
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        .navigationTitle("Чаты").navigationBarTitleDisplayMode(.inline)
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
                    Text(chat.emoji ?? "💬").font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(chat.title).font(.system(.subheadline, design: .rounded).weight(.semibold)).lineLimit(1)
                        Text(chat.model).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .padding(14)
                .glassSurface(radius: 18)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(allowsFullSwipe: false) {
                Button("Удалить", role: .destructive) { deleting = chat.id }.disabled(store.isSending)
                Button(archived ? "Вернуть" : "В архив") { store.archiveChat(chat.id, archived: !archived) }.tint(.orange).disabled(store.isSending)
            }
        }
    }
    private var emptyChats: some View {
        VStack(spacing: 14) {
            Text("🪄").font(.system(size: 54))
            Text("Чатов пока нет,\nно творить волшебство можно начать в любой момент").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { store.newChat(); if let id = store.selectedChatID { path.append(.chat(id)) } } label: { Label("Новый чат", systemImage: "square.and.pencil") }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .disabled(store.isSending)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .glassSurface(radius: 22)
    }
    private var settingsList: some View {
        SettingsScreen(openImages: { path.append(.images) })
    }
    private var chatDetail: some View {
        ZStack {
            LiquidBackground()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    modelMenu
                    Menu {
                        ForEach(["default", "low", "medium", "high", "xhigh", "max"], id: \.self) { level in
                            Button { store.setReasoning(level) } label: { Label(level == "xhigh" ? "xHigh" : level.capitalized, systemImage: store.selectedChat?.reasoning == level ? "checkmark" : "brain") }
                        }
                    } label: {
                        Label((store.selectedChat?.reasoning ?? "default").capitalized, systemImage: "brain")
                            .font(.caption)
                            .padding(10)
                            .glassCapsule()
                    }.disabled(store.isSending)
                    Button {
                        store.setWebSearch(store.selectedChat?.webSearch != true)
                    } label: {
                        Label("Сеть", systemImage: "globe")
                            .font(.caption)
                            .padding(10)
                            .background(store.selectedChat?.webSearch == true ? Palette.accent : Color.clear, in: Capsule())
                            .glassCapsule(tint: store.selectedChat?.webSearch == true ? Palette.accent : .clear)
                            .foregroundStyle(store.selectedChat?.webSearch == true ? .black : Palette.accent)
                    }
                        .disabled(store.isSending).help("Веб-поиск выполняет провайдер")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            if store.selectedChat?.messages.isEmpty != false { welcome }
                            ForEach(store.selectedChat?.messages ?? []) { message in
                                MessageView(message: message, waiting: store.isSending && message.id == store.selectedChat?.messages.last?.id)
                                    .id(message.id)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
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
                                    .font(.caption).padding(9).glassCapsule()
                            }.padding(.bottom, 6)
                        }
                    }
                }
                composer
            }
        }
        .navigationTitle(store.selectedChat?.title ?? "Новый чат")
        .navigationBarTitleDisplayMode(.inline)
        .background(BackTitleConfigurator())
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Статистика", systemImage: "chart.bar") { stats = true }
                Button("Провайдеры", systemImage: "slider.horizontal.3") { settings = true }
            }
        }
    }
    private var welcome: some View {
        VStack(alignment: .center, spacing: 16) {
            ZStack {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(color: GlassPalette.accent.opacity(0.30), radius: 24, x: 0, y: 10)

                Text(store.selectedChat?.emoji ?? "✨")
                    .font(.system(size: 26))
                    .offset(y: -46)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Text("Давай начнём.").font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Твои модели. Твои идеи.\nОдин спокойный уголок для диалогов.").foregroundStyle(.secondary)
            if store.providers.isEmpty { Button("Подключить провайдера", systemImage: "plus") { settings = true }.buttonStyle(GlassButtonStyle()) }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
        .padding(24)
        .glassSurface(radius: 24)
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
            .padding(10)
            .glassCapsule()
        }
        .disabled(store.isSending)
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { a in
                            AttachmentThumb(attachment: a) {
                                attachments.removeAll { $0.id == a.id }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            TextField("Напиши что-нибудь…", text: $input, axis: .vertical).lineLimit(1...7)
            if let reason = store.imageSupportWarning(for: attachments) {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(store.imageSupportError(for: attachments) != nil ? Color.red : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Menu {
                    Button("Файлы", systemImage: "folder") { importing = true }
                    Button("Галерея", systemImage: "photo.on.rectangle") { gallery = true }
                    Button("Камера", systemImage: "camera") {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { camera = true } else { error = "Камера недоступна" }
                    }
                } label: {
                    Image(systemName: "paperclip").frame(width: 34, height: 34).glassCapsule()
                }
                Spacer()
                if store.isSending {
                    Button { store.stop() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.red.opacity(0.9)))
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
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(GlassPalette.accentGradient, in: Circle())
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
        .padding(14)
        .glassSurface(radius: 24)
        .padding(12)
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
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(Palette.accent)
                    }
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
        .padding(.top, 5)
        .padding(.trailing, 5)
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
                systemImage: isUser ? "person.fill" : "sparkle"
            )
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(isUser ? GlassPalette.accent : GlassPalette.cyan)

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
                                    .frame(width: 108, height: 108)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                        }
                    }
                }
            }

            ForEach(files) { a in
                Label(a.name, systemImage: "doc.fill")
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 22, tint: isUser ? GlassPalette.accent : GlassPalette.violet)
    }
}
