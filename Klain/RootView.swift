import SwiftUI

// MARK: - Root: ad on top, all chats below, "+" menu top-right, swipe-right side menu.
struct RootView: View {
    @EnvironmentObject var store: ChatStore
    @AppStorage(KlainThemeStorage.key) private var themeRaw: String = AppTheme.dark.rawValue
    @State private var menuOpen = false
    @State private var showNewMenu = false
    @State private var path: [Route] = []

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .dark }

    enum Route: Hashable { case chat(UUID), images(UUID), statsModels, statsMessages, statsPhotos, providers, author }

    var body: some View {
        NavigationStack(path: $path) {
            mainScreen
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .chat(let id): ChatView(chatID: id, theme: theme, openMenu: { menuOpen = true })
                    case .images(let id): ImageChatView(chatID: id, theme: theme, openMenu: { menuOpen = true })
                    case .statsModels: ModelsStatsView(theme: theme)
                    case .statsMessages: MessagesStatsView(theme: theme)
                    case .statsPhotos: PhotosStatsView(theme: theme)
                    case .providers: ProvidersView(theme: theme)
                    case .author: AuthorView(theme: theme)
                    }
                }
        }
        .hideSystemNavBar()
        .glassContainer()
        .overlay {
            if menuOpen {
                SideMenuView(theme: theme, close: { menuOpen = false }, path: $path)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: menuOpen)
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { v in
                    if v.startLocation.x < 60 && v.translation.width > 80 { menuOpen = true }
                    else if menuOpen && v.translation.width < -80 { menuOpen = false }
                }
        )
    }

    private var mainScreen: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(spacing: 0) {
                // Ad is ALWAYS at the top.
                AdCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Header row: title capsule + "+".
                HStack {
                    Text("klain")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(KlainColors.text)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .glassCapsule()
                    Spacer()
                    Button { showNewMenu = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(KlainColors.text)
                            .frame(width: 44, height: 44)
                            .glassCircle()
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Новый чат", isPresented: $showNewMenu) {
                        Button("Чат с ИИ") { createChat(kind: "chat") }
                        Button("Чат с картинками") { createChat(kind: "images") }
                        Button("Отмена", role: .cancel) {}
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // All chats.
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.activeChats) { chat in
                            ChatRow(chat: chat) {
                                if chat.isImageChat { path.append(.images(chat.id)) }
                                else { path.append(.chat(chat.id)) }
                            }
                        }
                        if store.activeChats.isEmpty {
                            Text("Чатов пока нет")
                                .font(.subheadline)
                                .foregroundStyle(KlainColors.secondary)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func createChat(kind: String) {
        if kind == "images" { store.newImageChat() } else { store.newChat() }
        if let id = store.selectedChatID {
            if kind == "images" { path.append(.images(id)) } else { path.append(.chat(id)) }
        }
    }
}

// MARK: - Ad card (single glass block).
struct AdCard: View {
    var body: some View {
        Link(destination: URL(string: "https://cheapvibecode.ru/ref/FJEU3K8DC9")!) {
            HStack(spacing: 12) {
                Image("AdLogo").resizable().scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Реклама").font(.caption2).foregroundStyle(KlainColors.secondary)
                    Text("CheapVibeCode").font(.headline).foregroundStyle(KlainColors.text)
                    Text("Дешёвые токены для 30+ ИИ-моделей").font(.caption).foregroundStyle(KlainColors.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").foregroundStyle(KlainColors.secondary)
            }
            .padding(14)
            .glassRounded(22)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat row. Image chats get a pastel gradient marker.
private struct ChatRow: View {
    let chat: Chat
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                ZStack {
                    if chat.isImageChat {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [
                                Color(red: 0.99, green: 0.78, blue: 0.86),
                                Color(red: 0.78, green: 0.86, blue: 0.99),
                                Color(red: 0.86, green: 0.98, blue: 0.88)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 42, height: 42)
                    }
                    Text(chat.emoji ?? "💬").font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(chat.title).font(.subheadline.weight(.semibold)).foregroundStyle(KlainColors.text).lineLimit(1)
                    Text(chat.model).font(.system(size: 10, design: .monospaced)).foregroundStyle(KlainColors.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .glassRounded(18)
        }
        .buttonStyle(.plain)
    }
}
