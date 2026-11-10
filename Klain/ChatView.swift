import SwiftUI

// MARK: - AI chat. No stats/settings buttons. Jump-to-latest ALWAYS visible.
struct ChatView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let chatID: UUID
    let theme: AppTheme
    let openMenu: () -> Void

    @State private var input = ""
    @State private var attachments: [Attachment] = []
    @State private var importFile = false
    @State private var errMessage: String?

    private var chat: Chat? { store.chats.first { $0.id == chatID } }

    var body: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(spacing: 0) {
                ScreenHeader(title: chat?.title ?? "Новый чат", theme: theme) {
                    RoundGlassButton(icon: "chevron.left") { dismiss() }
                } trailing: {
                    // NO stats / settings buttons in AI chat.
                    Color.clear.frame(width: 44, height: 44)
                }

                // Controls chips (model / reasoning / web) — single style.
                HStack(spacing: 8) {
                    modelChip
                    reasoningChip
                    webChip
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                messageList

                // Jump-to-latest: ALWAYS visible, even when already at bottom.
                Button {
                    scrollToBottom()
                } label: {
                    Label("К последнему сообщению", systemImage: "chevron.down")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(KlainColors.text)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .glassCapsule()
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)

                composer
            }
        }
        .hideSystemNavBar()
        .onAppear { store.selectedChatID = chatID }
        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
            if v.startLocation.x < 60 && v.translation.width > 80 { openMenu() }
        })
        .alert("Ошибка", isPresented: Binding(get: { errMessage != nil }, set: { if !$0 { errMessage = nil } })) {
            Button("OK") { errMessage = nil }
        } message: { Text(errMessage ?? "") }
        .fileImporter(isPresented: $importFile, allowedContentTypes: [.image, .pdf, .text, .data], allowsMultipleSelection: true) { result in
            handleFiles(result)
        }
    }

    // MARK: message list
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(chat?.messages ?? []) { m in
                        MessageBubble(message: m)
                            .id(m.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chat?.messages.count) { _ in scroll(proxy) }
            .onChange(of: chat?.messages.last?.text) { _ in scroll(proxy) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }
    private func scrollToBottom() {
        // Posting a notification is unnecessary; ScrollViewReader re-reads via id.
        // Trigger a harmless state ping so onChange re-fires.
        NotificationCenter.default.post(name: .klainScrollBottom, object: nil)
    }

    // MARK: controls
    private var modelChip: some View {
        Menu {
            ForEach(store.providers) { p in
                Section(p.name) {
                    ForEach(p.models ?? []) { m in
                        Button { store.select(p, model: m.id) } label: {
                            Text(m.name.isEmpty ? m.id : m.name)
                        }
                    }
                }
            }
        } label: {
            ChipLabel(text: chat?.model ?? "Выбрать модель", icon: nil, chevron: true)
        }
    }
    private var reasoningChip: some View {
        Menu {
            ForEach(["default", "low", "medium", "high", "xhigh", "max"], id: \.self) { level in
                Button { store.setReasoning(level) } label: {
                    Text(level == "xhigh" ? "xHigh" : level.capitalized)
                }
            }
        } label: {
            ChipLabel(text: (chat?.reasoning ?? "default").capitalized, icon: "brain", chevron: false)
        }
    }
    private var webChip: some View {
        Button { store.setWebSearch(chat?.webSearch != true) } label: {
            ChipLabel(text: "Сеть", icon: "globe", chevron: false)
        }
        .buttonStyle(.plain)
    }

    // MARK: composer — identical to ImageChatView
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Attachment button opens Files, NEVER providers.
            Button { importFile = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(KlainColors.text)
                    .frame(width: 38, height: 38)
                    .glassCircle()
            }
            .buttonStyle(.plain)

            TextField("Напиши что-нибудь…", text: $input, axis: .vertical)
                .lineLimit(1...7)
                .foregroundStyle(KlainColors.text)
                .tint(KlainColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            if store.isSending {
                Button { store.stop() } label: {
                    Image(systemName: "stop.fill").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(KlainColors.text)
                        .frame(width: 38, height: 38).glassCircle()
                }.buttonStyle(.plain)
            } else {
                Button { send() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlainColors.text)
                        .frame(width: 38, height: 38).glassCircle()
                }
                .buttonStyle(.plain)
                .disabled(store.activeProvider == nil || chat?.model.isEmpty != false || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassRounded(24)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func send() {
        let text = input
        input = ""
        store.selectedChatID = chatID
        Task { await store.send(text, attachments: attachments) }
        attachments = []
    }

    private func handleFiles(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get() {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                attachments.append(Attachment(name: url.lastPathComponent, mime: "application/octet-stream", data: data))
            }
        } catch let e { errMessage = e.localizedDescription }
    }
}

// MARK: - User message in a block; assistant message plain text.
struct MessageBubble: View {
    let message: Message
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message.role == "user" ? "ТЫ" : (message.modelName ?? "Модель"),
                  systemImage: message.role == "user" ? "person" : "sparkle")
                .font(.caption2.weight(.bold))
                .foregroundStyle(KlainColors.secondary)
            MarkdownMessage(text: message.text)
            if let u = message.usage {
                Text("↑ \(u.input ?? 0)   ↓ \(u.output ?? 0) токенов")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(KlainColors.tertiary)
            }
        }
        .padding(message.role == "user" ? 14 : 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassRounded(message.role == "user" ? 18 : 0) // user gets a block
    }
}

// MARK: - Shared chip (same style in chat and image chat).
struct ChipLabel: View {
    let text: String
    let icon: String?
    let chevron: Bool
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11)) }
            Text(text).lineLimit(1)
            if chevron { Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)) }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(KlainColors.text)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassCapsule()
    }
}

extension Notification.Name {
    static let klainScrollBottom = Notification.Name("klainScrollBottom")
}
