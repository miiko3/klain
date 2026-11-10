import SwiftUI

struct ProviderPreset: Identifiable {
    let id: String; let name: String; let url: String; let symbol: String
    static let all: [ProviderPreset] = [
        .init(id: "anthropic", name: "Anthropic", url: "https://api.anthropic.com/v1", symbol: "a.square"),
        .init(id: "openai", name: "OpenAI", url: "https://api.openai.com/v1", symbol: "sparkle"),
        .init(id: "google", name: "Google", url: "https://generativelanguage.googleapis.com/v1beta/openai", symbol: "sparkles"),
        .init(id: "openrouter", name: "OpenRouter", url: "https://openrouter.ai/api/v1", symbol: "arrow.triangle.branch"),
        .init(id: "vercel", name: "Vercel AI Gateway", url: "https://ai-gateway.vercel.sh/v1", symbol: "triangle"),
        .init(id: "custom", name: "Пользовательский провайдер", url: "", symbol: "slider.horizontal.3")
    ]
}

// MARK: - Providers list (single screen, no nested NavigationStack).
struct ProvidersView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let theme: AppTheme
    @State private var editing: Provider?
    @State private var error: String?

    var body: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(spacing: 0) {
                ScreenHeader(title: "Провайдеры", theme: theme) {
                    RoundGlassButton(icon: "chevron.left") { dismiss() }
                } trailing: {
                    TextGlassButton(title: "Готово") { dismiss() }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        section("ЧЕРНОВИКИ")
                        if store.drafts.isEmpty { hint("Нет черновиков") }
                        else {
                            ForEach(store.drafts) { p in
                                providerRow(p, subtitle: "черновик", icon: "square.and.pencil") { editing = p }
                                    .swipeActions { Button(role: .destructive) { try? store.deleteDraft(p.id) } label: { Label("Удалить", systemImage: "trash") } }
                            }
                        }
                        section("ПОДКЛЮЧЕНО")
                        if store.providers.isEmpty { hint("Добавь свой первый API-ключ") }
                        else {
                            ForEach(store.providers) { p in
                                providerRow(p, subtitle: "\(p.models?.count ?? 0) моделей", icon: "circle.grid.2x2") { editing = p }
                                    .swipeActions { Button(role: .destructive) { try? store.removeProvider(p.id) } label: { Label("Удалить", systemImage: "trash") } }
                            }
                        }
                        section("ДОБАВИТЬ ПРОВАЙДЕРА")
                        ForEach(ProviderPreset.all) { preset in
                            Button {
                                editing = Provider(name: preset.name, baseURL: preset.url, apiKey: "",
                                                   kind: preset.id, slug: preset.id, models: [], headers: [])
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: preset.symbol).font(.system(size: 17)).frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.name).font(.subheadline.weight(.semibold))
                                        if !preset.url.isEmpty { Text(preset.url).font(.system(size: 10, design: .monospaced)).foregroundStyle(KlainColors.secondary).lineLimit(1) }
                                    }
                                    Spacer()
                                    Image(systemName: "plus").font(.system(size: 13)).foregroundStyle(KlainColors.tertiary)
                                }
                                .padding(14).glassRounded(16)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Ключи и пользовательские заголовки хранятся в Keychain. Список моделей приходит от провайдера.")
                            .font(.caption2).foregroundStyle(KlainColors.secondary)
                    }
                    .padding(16)
                }
            }
        }
        .hideSystemNavBar()
        .sheet(item: $editing) { ProviderEditor(provider: $0, theme: theme, error: $error) }
        .alert("Ошибка", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.caption.weight(.bold)).foregroundStyle(KlainColors.secondary).padding(.top, 8)
    }
    private func hint(_ t: String) -> some View {
        Text(t).font(.caption).foregroundStyle(KlainColors.secondary)
    }
    private func providerRow(_ p: Provider, subtitle: String, icon: String, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17)).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name.isEmpty ? "Новый провайдер" : p.name).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(KlainColors.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(KlainColors.tertiary)
            }
            .padding(14).glassRounded(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Provider editor (single screen).
struct ProviderEditor: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State var provider: Provider
    let theme: AppTheme
    @Binding var error: String?
    @State private var models: [ModelEntry] = []
    @State private var headers: [HeaderEntry] = []
    @State private var slug: String = "custom"
    @State private var loading = false
    @State private var filter = ""

    var body: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(spacing: 0) {
                ScreenHeader(title: provider.name.isEmpty ? "Новый провайдер" : provider.name, theme: theme) {
                    TextGlassButton(title: "Назад") { dismiss() }
                } trailing: {
                    TextGlassButton(title: "Сохранить") { save() }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        section("ПОДКЛЮЧЕНИЕ")
                        field("ID провайдера", text: $slug)
                        field("Отображаемое имя", text: $provider.name)
                        field("Базовый URL", text: $provider.baseURL)
                        field("Ключ API (необязательно)", text: $provider.apiKey)
                        Text("Для своего шлюза можно оставить ключ пустым и задать авторизацию через заголовки.")
                            .font(.caption2).foregroundStyle(KlainColors.secondary)

                        section("МОДЕЛИ")
                        Button {
                            loading = true
                            Task {
                                defer { loading = false }
                                do { models = try await APIClient().models(provider: provider) }
                                catch { error = error?.isEmpty == false ? error! : error.debugDescription }
                            }
                        } label: {
                            Label(loading ? "Загрузка…" : "Загрузить модели из API", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .padding(12).glassCapsule()
                        }
                        .buttonStyle(.plain)
                        field("Фильтр моделей", text: $filter)
                        ForEach(Array(models.enumerated()), id: \.element.id) { i, m in
                            if filter.isEmpty || (m.id + m.name).localizedCaseInsensitiveContains(filter) {
                                HStack {
                                    TextField("model-id", text: Binding(get: { models[i].id }, set: { models[i].id = $0 }))
                                    TextField("Имя", text: Binding(get: { models[i].name }, set: { models[i].name = $0 }))
                                }
                                .font(.system(size: 12, design: .monospaced))
                                .padding(10).glassRounded(12)
                            }
                        }
                        Button { models.append(ModelEntry(id: "", name: "")) } label: {
                            Label("Добавить модель", systemImage: "plus").font(.system(size: 14, weight: .semibold))
                                .padding(12).glassCapsule()
                        }.buttonStyle(.plain)

                        section("ЗАГОЛОВКИ")
                        ForEach(Array(headers.enumerated()), id: \.element.id) { i, _ in
                            HStack {
                                TextField("Header-Name", text: Binding(get: { headers[i].name }, set: { headers[i].name = $0 }))
                                TextField("Значение", text: Binding(get: { headers[i].value }, set: { headers[i].value = $0 }))
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .padding(10).glassRounded(12)
                        }
                        Button { headers.append(HeaderEntry()) } label: {
                            Label("Добавить заголовок", systemImage: "plus").font(.system(size: 14, weight: .semibold))
                                .padding(12).glassCapsule()
                        }.buttonStyle(.plain)

                        Text("Добавление API-ключа не гарантирует генерацию изображений, видео и аудио.")
                            .font(.caption2).foregroundStyle(KlainColors.secondary)
                    }
                    .padding(16)
                }
            }
        }
        .hideSystemNavBar()
        .onAppear {
            models = provider.models ?? []
            headers = provider.headers ?? []
            slug = provider.slug ?? "custom"
        }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.caption.weight(.bold)).foregroundStyle(KlainColors.secondary).padding(.top, 8)
    }
    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.system(size: 14))
            .padding(12).glassRounded(14)
    }
    private func save() {
        provider.slug = slug.trimmingCharacters(in: .whitespaces)
        provider.models = models.filter { !$0.id.trimmingCharacters(in: .whitespaces).isEmpty }
        provider.headers = headers.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !provider.name.isEmpty, provider.baseURL.hasPrefix("http"),
              !provider.models!.isEmpty else {
            error = "Укажи имя, корректный URL и хотя бы одну модель"; return
        }
        do { try store.configure(provider); dismiss() }
        catch { error = error.debugDescription }
    }
}
