import SwiftUI

struct ProviderPreset: Identifiable {
    let id: String; let name: String; let url: String; let symbol: String
    static let all: [ProviderPreset] = [
        .init(id: "anthropic", name: "Anthropic", url: "https://api.anthropic.com/v1", symbol: "a.square"),
        .init(id: "openai", name: "OpenAI", url: "https://api.openai.com/v1", symbol: "sparkle"),
        .init(id: "google", name: "Google", url: "https://generativelanguage.googleapis.com/v1beta/openai", symbol: "sparkles"),
        .init(id: "openrouter", name: "OpenRouter", url: "https://openrouter.ai/api/v1", symbol: "arrow.triangle.branch"),
        .init(id: "vercel", name: "Vercel AI Gateway", url: "https://ai-gateway.vercel.sh/v1", symbol: "triangle.fill"),
        .init(id: "custom", name: "Пользовательский провайдер", url: "", symbol: "slider.horizontal.3")
    ]
}

struct ProvidersView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Provider?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section("ЧЕРНОВИКИ") { ForEach(store.drafts) { p in Button(p.name) { editing = p } } }
                Section("ПОДКЛЮЧЕНО") {
                    if store.providers.isEmpty { Text("Добавь свой первый API-ключ").foregroundStyle(.secondary) }
                    ForEach(store.providers) { p in
                        Button { editing = p } label: { HStack { Label(p.name, systemImage: "circle.grid.2x2"); Spacer(); Text("\(p.models?.count ?? 0) моделей").font(.caption).foregroundStyle(.secondary) } }
                            .swipeActions { Button("Удалить", role: .destructive) { do { try store.removeProvider(p.id) } catch { self.error = error.localizedDescription } }.disabled(store.isSending) }
                    }
                }
                Section("ДОБАВИТЬ ПРОВАЙДЕРА") {
                    ForEach(ProviderPreset.all) { preset in Button { editing = Provider(name: preset.name, baseURL: preset.url, apiKey: "", kind: preset.id, slug: preset.id) } label: { Label(preset.name, systemImage: preset.symbol).padding(.vertical, 7) } }
                }
                Section { Text("Ключи и пользовательские заголовки хранятся в Keychain. Список моделей приходит от провайдера: доступ зависит от тарифа и прав ключа.").font(.caption).foregroundStyle(.secondary) }
                Section("АВТОР KLAIN") {
                    Link(destination: URL(string: "https://github.com/miiko3")!) { Label("GitHub · miiko3", systemImage: "chevron.left.forwardslash.chevron.right") }
                    Link(destination: URL(string: "https://www.threads.com/@klain_app")!) { Label("Threads · @klain_app", systemImage: "at") }
                    Link(destination: URL(string: "https://t.me/yetilov")!) { Label("Telegram · @yetilov", systemImage: "paperplane") }
                }
            }.scrollContentBackground(.hidden).background(Palette.background)
                .navigationTitle("Провайдеры").toolbar { Button("Готово") { dismiss() } }
                .sheet(item: $editing) { ProviderEditor(provider: $0) }
                .alert("Ошибка", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }.tint(Palette.accent).preferredColorScheme(.dark)
    }
}

struct ProviderEditor: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State var provider: Provider
    @State private var models: [ModelEntry] = []
    @State private var headers: [HeaderEntry] = []
    @State private var slug = ""
    @State private var query = ""
    @State private var error = ""
    @State private var loading = false
    @State private var ready = false
    @State private var saved = false
    @State private var showMediaNotice = false
    private let mediaNotice = "Добавление API-ключа не гарантирует генерацию изображений, видео и аудио. В klain и похожих чат-клиентах она доступна только при поддержке со стороны приложения, API-провайдера и выбранной модели. Для CheapVibeCode поддержка генерации медиа не подтверждена."
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            Form {
                Section("ПОДКЛЮЧЕНИЕ") {
                    TextField("ID провайдера", text: $slug)
                    TextField("Отображаемое имя", text: $provider.name)
                    TextField("Базовый URL", text: $provider.baseURL).keyboardType(.URL)
                    SecureField("Ключ API (необязательно)", text: $provider.apiKey)
                    Text(mediaNotice).font(.caption).foregroundStyle(.secondary)
                    Text("Для своего шлюза можно оставить ключ пустым и задать авторизацию через заголовки.").font(.caption).foregroundStyle(.secondary)
                }
                Section("МОДЕЛИ") {
                    Button("Загрузить модели из API", systemImage: "arrow.clockwise") {
                        loading = true
                        Task { do { var p = provider; p.headers = headers; let loaded = try await APIClient().models(provider: p); for model in loaded { if let i = models.firstIndex(where: { $0.id == model.id }) { models[i].outputModalities = model.outputModalities } else { models.append(model) } }; error = "" } catch { self.error = error.localizedDescription }; loading = false }
                    }.disabled(loading)
                    if loading { ProgressView() }
                    TextField("Фильтр моделей", text: $query)
                    ForEach(models.indices.filter { query.isEmpty || models[$0].id.localizedCaseInsensitiveContains(query) || models[$0].name.localizedCaseInsensitiveContains(query) }, id: \.self) { index in
                        HStack {
                            VStack { TextField("model-id", text: $models[index].id); TextField("Отображаемое имя", text: $models[index].name).font(.caption) }
                            Button(role: .destructive) { models.remove(at: index) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                    }
                    Button("Добавить модель", systemImage: "plus") { query = ""; models.append(ModelEntry(id: "", name: "")) }
                }
                Section("ЗАГОЛОВКИ") {
                    ForEach($headers) { $h in HStack { VStack { TextField("Header-Name", text: $h.name); SecureField("Значение", text: $h.value) }; Button(role: .destructive) { headers.removeAll { $0.id == h.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless) } }
                    Button("Добавить заголовок", systemImage: "plus") { headers.append(HeaderEntry()) }
                }
                if !error.isEmpty { Section { Text(error).foregroundStyle(.red) } }
            }.textInputAutocapitalization(.never).autocorrectionDisabled().scrollContentBackground(.hidden).background(Palette.background)
                .navigationTitle(provider.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Назад") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).disabled(loading || store.isSending) } }
                .onAppear { if !ready { if let draft = store.drafts.first(where: { $0.id == provider.id }) { provider = draft }; models = provider.models ?? []; headers = provider.headers ?? []; slug = provider.slug ?? "custom"; ready = true } }
                .onChange(of: provider) { _, _ in persistDraft() }
                .onChange(of: models) { _, _ in persistDraft() }
                .onChange(of: headers) { _, _ in persistDraft() }
                .onChange(of: slug) { _, _ in persistDraft() }
                .onChange(of: scenePhase) { _, _ in persistDraft() }
                .onDisappear { persistDraft() }
                .alert("О генерации медиа", isPresented: $showMediaNotice) { Button("Понятно") { dismiss() } } message: { Text(mediaNotice) }
        }.preferredColorScheme(.dark).tint(Palette.accent)
    }
    private func save() {
        guard slug.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil else { error = "ID: строчные латинские буквы, цифры, дефис и подчёркивание"; return }
        guard !store.providers.contains(where: { $0.id != provider.id && $0.slug == slug }) else { error = "Этот ID уже используется"; return }
        guard let url = URL(string: provider.baseURL), url.scheme == "https", url.host != nil, !provider.name.isEmpty else { error = "Укажи имя и корректный HTTPS URL"; return }
        guard !models.isEmpty, models.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespaces).isEmpty }), Set(models.map(\.id)).count == models.count else { error = "Добавь хотя бы одну модель с уникальным ID"; return }
        guard headers.allSatisfy({ $0.name.range(of: "^[!#$%&'*+.^_`|~0-9A-Za-z-]+$", options: .regularExpression) != nil && !$0.value.contains("\n") && !$0.value.contains("\r") }) else { error = "Некорректный HTTP-заголовок"; return }
        provider.slug = slug; provider.models = models; provider.headers = headers
        do { try store.configure(provider); try store.deleteDraft(provider.id); saved = true; if store.activeProvider?.id == provider.id || store.activeProvider == nil { store.select(provider, model: models.first!.id) }; showMediaNotice = true } catch { self.error = error.localizedDescription }
    }
    private func persistDraft() { guard ready, !saved else { return }; var draft = provider; draft.models = models; draft.headers = headers; draft.slug = slug; store.saveDraft(draft) }
}
