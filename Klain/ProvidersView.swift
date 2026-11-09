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

struct ProvidersView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Provider?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14 * AppScale.k) {
                        card(title: "ЧЕРНОВИКИ", tint: GlassPalette.violet) {
                            if store.drafts.isEmpty {
                                empty("Нет черновиков")
                            } else {
                                ForEach(store.drafts) { p in
                                    providerRow(
                                        title: p.name.isEmpty ? "Новый провайдер" : p.name,
                                        subtitle: "черновик",
                                        icon: "square.and.pencil",
                                        tint: GlassPalette.violet,
                                        trailing: nil
                                    ) { editing = p }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            do { try store.deleteDraft(p.id) } catch { self.error = error.localizedDescription }
                                        } label: { Label("Удалить", systemImage: "trash") }
                                    }
                                }
                            }
                        }

                        card(title: "ПОДКЛЮЧЕНО", tint: GlassPalette.mint) {
                            if store.providers.isEmpty {
                                empty("Добавь свой первый API-ключ")
                            } else {
                                ForEach(store.providers) { p in
                                    providerRow(
                                        title: p.name,
                                        subtitle: "\(p.models?.count ?? 0) моделей",
                                        icon: "circle.grid.2x2",
                                        tint: GlassPalette.mint,
                                        trailing: nil
                                    ) { editing = p }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            do { try store.removeProvider(p.id) } catch { self.error = error.localizedDescription }
                                        } label: { Label("Удалить", systemImage: "trash") }
                                        .disabled(store.isSending)
                                    }
                                }
                            }
                        }

                        card(title: "ДОБАВИТЬ ПРОВАЙДЕРА", tint: GlassPalette.cyan) {
                            ForEach(ProviderPreset.all) { preset in
                                providerRow(
                                    title: preset.name,
                                    subtitle: nil,
                                    icon: preset.symbol,
                                    tint: GlassPalette.cyan,
                                    trailing: nil
                                ) { editing = Provider(name: preset.name, baseURL: preset.url, apiKey: "", kind: preset.id, slug: preset.id) }
                            }
                        }

                        Text("Ключи и пользовательские заголовки хранятся в Keychain. Список моделей приходит от провайдера: доступ зависит от тарифа и прав ключа.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16 * AppScale.k)
                    }
                    .padding(16 * AppScale.k)
                }
            }
            .glassContainer()
            .navigationTitle("Провайдеры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(item: $editing) { ProviderEditor(provider: $0) }
            .alert("Ошибка", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
        .tint(Color.primary)
    }

    private func card<Content: View>(title: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4 * AppScale.k)
            VStack(spacing: 8) { content() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14 * AppScale.k)
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12 * AppScale.k)
    }

    private func providerRow(title: String, subtitle: String?, icon: String, tint: Color, trailing: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14 * AppScale.k, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32 * AppScale.k, height: 32 * AppScale.k)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10 * AppScale.k, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing).font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11 * AppScale.k, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10 * AppScale.k)
            .contentShape(RoundedRectangle(cornerRadius: 16 * AppScale.k, style: .continuous))
        }
        .buttonStyle(.plain)
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
    private let mediaNotice = "Добавление API-ключа не гарантирует генерацию изображений, видео и аудио. В klain раздел «Картинки» работает, если выбранный провайдер и модель поддерживают отдельный API генерации изображений."
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14 * AppScale.k) {
                        connectionSection
                        modelsSection
                        headersSection
                        Text(mediaNotice)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16 * AppScale.k)
                        if !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14 * AppScale.k)
                        }
                    }
                    .padding(16 * AppScale.k)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .glassContainer()
            .navigationTitle(provider.name.isEmpty ? "Новый провайдер" : provider.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(loading || store.isSending)
                }
            }
            .onAppear { if !ready { if let draft = store.drafts.first(where: { $0.id == provider.id }) { provider = draft }; models = provider.models ?? []; headers = provider.headers ?? []; slug = provider.slug ?? "custom"; ready = true } }
            .onChange(of: provider) { _, _ in persistDraft() }
            .onChange(of: models) { _, _ in persistDraft() }
            .onChange(of: headers) { _, _ in persistDraft() }
            .onChange(of: slug) { _, _ in persistDraft() }
            .onChange(of: scenePhase) { _, _ in persistDraft() }
            .onDisappear { persistDraft() }
            .alert("О генерации медиа", isPresented: $showMediaNotice) { Button("Понятно") { dismiss() } } message: { Text(mediaNotice) }
        }.tint(Color.primary)
    }
    private var connectionSection: some View {
        editorCard(title: "ПОДКЛЮЧЕНИЕ", tint: GlassPalette.accent) {
            fieldBox {
                VStack(spacing: 0) {
                    TextField("ID провайдера", text: $slug)
                        .padding(12 * AppScale.k)
                    TextField("Отображаемое имя", text: $provider.name)
                        .padding(12 * AppScale.k)
                    TextField("Базовый URL", text: $provider.baseURL)
                        .keyboardType(.URL)
                        .padding(12 * AppScale.k)
                    SecureField("Ключ API (необязательно)", text: $provider.apiKey)
                        .padding(12 * AppScale.k)
                }
            }
            Text("Для своего шлюза можно оставить ключ пустым и задать авторизацию через заголовки.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var modelsSection: some View {
        editorCard(title: "МОДЕЛИ", tint: GlassPalette.violet) {
            Button(action: loadModels) {
                HStack(spacing: 8) {
                    if loading { ProgressView().scaleEffect(0.8) }
                    Image(systemName: "arrow.clockwise")
                    Text(loading ? "Загружаю…" : "Загрузить модели из API")
                }
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(loading)

            fieldBox {
                TextField("Фильтр моделей", text: $query)
                    .padding(12 * AppScale.k)
            }

            if models.contains(where: { $0.supportsVision == true }) {
                Text("Модели с отметкой «видит фото» принимают изображения.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(visibleModelIndexes, id: \.self) { index in
                modelRow(index)
            }

            Button {
                query = ""
                models.append(ModelEntry(id: "", name: ""))
            } label: {
                Label("Добавить модель", systemImage: "plus")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    private var visibleModelIndexes: [Int] {
        models.indices.filter { index in
            if query.isEmpty { return true }
            return models[index].id.localizedCaseInsensitiveContains(query)
                || models[index].name.localizedCaseInsensitiveContains(query)
        }
    }

    private func modelRow(_ index: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("model-id", text: $models[index].id)
                    .font(.system(.caption, design: .monospaced))
                TextField("Отображаемое имя", text: $models[index].name)
                    .font(.system(size: 10 * AppScale.k, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            modelBadge(index)
            Button { models.remove(at: index) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12 * AppScale.k, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(10 * AppScale.k)
    }

    @ViewBuilder
    private func modelBadge(_ index: Int) -> some View {
        if models[index].supportsVision == true {
            VisionBadge()
        } else if models[index].supportsVision == false {
            Text("текст")
                .font(.system(size: 9 * AppScale.k, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7 * AppScale.k)
                .padding(.vertical, 3 * AppScale.k)
        }
    }

    private var headersSection: some View {
        editorCard(title: "ЗАГОЛОВКИ", tint: GlassPalette.cyan) {
            ForEach($headers) { $h in
                headerRow($h)
            }
            Button {
                headers.append(HeaderEntry())
            } label: {
                Label("Добавить заголовок", systemImage: "plus")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    private func headerRow(_ header: Binding<HeaderEntry>) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Header-Name", text: header.name)
                    .font(.system(.caption, design: .monospaced))
                SecureField("Значение", text: header.value)
                    .font(.caption)
            }
            Button { headers.removeAll { $0.id == header.wrappedValue.id } } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12 * AppScale.k, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(10 * AppScale.k)
    }

    private func editorCard<Content: View>(title: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4 * AppScale.k)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14 * AppScale.k)
    }
    private func fieldBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
    }
    private func loadModels() {
        loading = true
        Task {
            do {
                var p = provider
                p.headers = headers
                let loaded = try await APIClient().models(provider: p)
                for model in loaded {
                    if let i = models.firstIndex(where: { $0.id == model.id }) {
                        models[i].outputModalities = model.outputModalities
                        models[i].inputModalities = model.inputModalities
                        if !model.name.isEmpty { models[i].name = model.name }
                    } else {
                        models.append(model)
                    }
                }
                error = ""
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
    private func save() {
        models = models.map {
            ModelEntry(
                id: $0.id.trimmingCharacters(in: .whitespacesAndNewlines),
                name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                outputModalities: $0.outputModalities,
                inputModalities: $0.inputModalities
            )
        }
        guard slug.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil else { error = "ID: строчные латинские буквы, цифры, дефис и подчёркивание"; return }
        guard !store.providers.contains(where: { $0.id != provider.id && $0.slug == slug }) else { error = "Этот ID уже используется"; return }
        guard let url = URL(string: provider.baseURL), url.scheme == "https", url.host != nil, !provider.name.isEmpty else { error = "Укажи имя и корректный HTTPS URL"; return }
        guard !models.isEmpty, models.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespaces).isEmpty }), Set(models.map(\.id)).count == models.count else { error = "Добавь хотя бы одну модель с уникальным ID"; return }
        guard headers.allSatisfy({ $0.name.range(of: "^[!#$%&'*+.^_`|~0-9A-Za-z-]+$", options: .regularExpression) != nil && !$0.value.contains("\n") && !$0.value.contains("\r") }) else { error = "Некорректный HTTP-заголовок"; return }
        provider.slug = slug; provider.models = models; provider.headers = headers
        do { try store.configure(provider); try store.deleteDrafts(matching: provider); saved = true; if store.activeProvider?.id == provider.id || store.activeProvider == nil { store.select(provider, model: models.first!.id) }; showMediaNotice = true } catch { self.error = error.localizedDescription }
    }
    private func persistDraft() { guard ready, !saved else { return }; var draft = provider; draft.models = models; draft.headers = headers; draft.slug = slug; store.saveDraft(draft) }
}
