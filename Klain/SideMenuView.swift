import SwiftUI

// MARK: - Full-screen side menu (opens on swipe-right).
struct SideMenuView: View {
    @EnvironmentObject var store: ChatStore
    let theme: AppTheme
    let close: () -> Void
    @Binding var path: [RootView.Route]
    @AppStorage(KlainThemeStorage.key) private var themeRaw: String = AppTheme.dark.rawValue
    @State private var statsExpanded = false

    var body: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(alignment: .leading, spacing: 0) {
                // Header: close + title (same capsule sizes).
                HStack {
                    RoundGlassButton(icon: "xmark", action: close)
                    Spacer()
                    TitleCapsule(title: "Меню")
                    Spacer()
                    // symmetric spacer so title stays centered
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Statistics section with THREE separate sub-pages.
                        sectionHeader("СТАТИСТИКА")
                        menuButton(title: "По часто используемым моделям", icon: "cpu") {
                            path.append(.statsModels); close()
                        }
                        menuButton(title: "По кол-ву сообщений", icon: "bubble.left.and.bubble.right") {
                            path.append(.statsMessages); close()
                        }
                        menuButton(title: "По кол-ву сгенерированных фото", icon: "photo") {
                            path.append(.statsPhotos); close()
                        }

                        // Theme picker.
                        sectionHeader("ТЕМА")
                        HStack(spacing: 8) {
                            ForEach(AppTheme.allCases) { t in
                                Button {
                                    themeRaw = t.rawValue
                                } label: {
                                    Text(t.label)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(KlainColors.text)
                                        .padding(.horizontal, 12).padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .glassCapsule()
                                        .opacity(theme == t ? 1 : 0.55)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        sectionHeader("ПРИЛОЖЕНИЕ")
                        menuButton(title: "Провайдеры", icon: "slider.horizontal.3") {
                            path.append(.providers); close()
                        }
                        menuButton(title: "Автор", icon: "person") {
                            path.append(.author); close()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t)
            .font(.caption.weight(.bold))
            .foregroundStyle(KlainColors.secondary)
            .padding(.top, 8)
    }

    private func menuButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(KlainColors.text)
                    .frame(width: 32)
                Text(title)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(KlainColors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(KlainColors.tertiary)
            }
            .padding(14)
            .glassRounded(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Three separate statistics screens.
private struct StatsPageScaffold<Content: View>: View {
    let title: String
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(spacing: 0) {
                ScreenHeader(title: title, theme: theme) {
                    RoundGlassButton(icon: "chevron.left") { dismiss() }
                } trailing: {
                    Color.clear.frame(width: 44, height: 44)
                }
                ScrollView { content().padding(16) }
            }
        }
        .hideSystemNavBar()
    }
}

struct ModelsStatsView: View {
    @EnvironmentObject var store: ChatStore
    let theme: AppTheme
    private var rows: [(String, Int)] {
        var counts: [String: Int] = [:]
        for r in store.records { counts[r.model, default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
    var body: some View {
        StatsPageScaffold(title: "По моделям", theme: theme) {
            if rows.isEmpty { emptyText("Нет данных") }
            else {
                ForEach(rows, id: \.0) { model, n in
                    HStack {
                        Text(model).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(n)").font(.system(size: 15, design: .monospaced))
                    }
                    .padding(14).glassRounded(16)
                }
            }
        }
    }
}

struct MessagesStatsView: View {
    @EnvironmentObject var store: ChatStore
    let theme: AppTheme
    private var rows: [(String, Int)] {
        store.activeChats.map { ($0.title, $0.messages.count) }.sorted { $0.1 > $1.1 }
    }
    var body: some View {
        StatsPageScaffold(title: "По сообщениям", theme: theme) {
            if rows.isEmpty { emptyText("Нет данных") }
            else {
                ForEach(rows, id: \.0) { title, n in
                    HStack {
                        Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer()
                        Text("\(n)").font(.system(size: 15, design: .monospaced))
                    }
                    .padding(14).glassRounded(16)
                }
            }
        }
    }
}

struct PhotosStatsView: View {
    @EnvironmentObject var store: ChatStore
    let theme: AppTheme
    var body: some View {
        StatsPageScaffold(title: "По фото", theme: theme) {
            HStack {
                Text("Сгенерировано изображений").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.generatedImages.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .padding(16).glassRounded(18)
            if store.generatedImages.isEmpty { emptyText("Пока нет изображений") }
        }
    }
}

private func emptyText(_ s: String) -> some View {
    Text(s).font(.subheadline).foregroundStyle(KlainColors.secondary).padding(.top, 40)
}

// MARK: - Author page.
struct AuthorView: View {
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss
    private let links: [(String, String)] = [
        ("GitHub · miiko3", "https://github.com/miiko3"),
        ("Threads · @klain_app", "https://www.threads.com/@klain_app"),
        ("Telegram · @yetilov", "https://t.me/yetilov"),
        ("Boosty · поддержать", "https://boosty.to/miilo3")
    ]
    var body: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(spacing: 0) {
                ScreenHeader(title: "Автор", theme: theme) {
                    RoundGlassButton(icon: "chevron.left") { dismiss() }
                } trailing: {
                    Color.clear.frame(width: 44, height: 44)
                }
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(links, id: \.0) { title, url in
                            Link(destination: URL(string: url)!) {
                                HStack {
                                    Text(title).font(.system(size: 15, weight: .regular, design: .rounded))
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.system(size: 12))
                                }
                                .padding(14).glassRounded(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .hideSystemNavBar()
    }
}
