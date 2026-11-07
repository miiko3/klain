import SwiftUI
import UIKit
import Photos

struct ImageStudioView: View {
    @EnvironmentObject var store: ChatStore
    @State private var prompt = ""
    @State private var providerID: UUID?
    @State private var model = ""
    @State private var size = "1024x1024"
    @State private var selected: GeneratedImage?
    @State private var settings = false
    @State private var notice: String?
    @FocusState private var focused: Bool

    private var provider: Provider? {
        if let id = providerID, let match = store.providers.first(where: { $0.id == id }) { return match }
        return store.activeProvider ?? store.providers.first
    }

    private var imageModels: [ModelEntry] {
        guard let provider else {
            return ImageModelCatalog.presets.map { ModelEntry(id: $0, name: $0, outputModalities: ["image"]) }
        }
        return ImageModelCatalog.models(from: provider.models ?? [])
    }

    private var canGenerate: Bool {
        provider != nil
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.isGeneratingImage
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    promptCard
                    optionsCard
                    if store.isGeneratingImage { generatingCard }
                    gallery
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Картинки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Провайдеры")
            }
        }
        .sheet(isPresented: $settings) { ProvidersView() }
        .sheet(item: $selected) { item in ImagePreviewSheet(image: item) }
        .alert(
            "Уведомление",
            isPresented: Binding(
                get: { notice != nil || store.error != nil },
                set: { value in
                    if !value { notice = nil; store.error = nil }
                }
            )
        ) {
            Button("OK") { notice = nil; store.error = nil }
        } message: {
            Text(notice ?? store.error ?? "")
        }
        .onAppear { prepare() }
        .onChange(of: providerID) { _, _ in
            let candidates = imageModels
            if !candidates.contains(where: { $0.id == model }) {
                model = candidates.first(where: { $0.id == store.imageModel })?.id ?? candidates.first?.id ?? ""
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(store.providers.isEmpty ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(store.providers.isEmpty ? "API не настроен" : "API подключён")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("Генерация изображений")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Опиши идею — модель нарисует её. Ключ и Base URL задаются в «Провайдерах» и не хранятся в коде.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Опиши изображение…", text: $prompt, axis: .vertical)
                .lineLimit(3...8)
                .focused($focused)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack {
                if !prompt.isEmpty {
                    Button("Очистить") { prompt = "" }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.providers.isEmpty {
                    Button("Подключить API") { settings = true }
                        .buttonStyle(GlassButtonStyle(prominent: true))
                } else if store.isGeneratingImage {
                    Button("Отменить") { store.cancelImageGeneration() }
                        .buttonStyle(GlassButtonStyle())
                } else {
                    Button { generate() } label: {
                        Label("Сгенерировать", systemImage: "sparkles")
                    }
                    .buttonStyle(GlassButtonStyle(prominent: true))
                    .disabled(!canGenerate)
                    .opacity(canGenerate ? 1 : 0.5)
                }
            }
        }
        .padding(18)
        .glassSurface(radius: 24)
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.providers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Провайдер").font(.caption).foregroundStyle(.secondary)
                    Menu {
                        ForEach(store.providers) { p in
                            Button { providerID = p.id } label: {
                                if provider?.id == p.id { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                            }
                        }
                    } label: {
                        menuLabel(provider?.name ?? "Выбери провайдера")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Модель").font(.caption).foregroundStyle(.secondary)
                Menu {
                    ForEach(imageModels) { entry in
                        Button { model = entry.id } label: {
                            if model == entry.id { Label(entry.name, systemImage: "checkmark") } else { Text(entry.name) }
                        }
                    }
                } label: {
                    menuLabel(model.isEmpty ? "Выбери модель" : model)
                }
                TextField("ID модели", text: $model)
                    .font(.system(.caption, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Размер").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(ImageModelCatalog.sizes, id: \.self) { value in
                        Button { size = value } label: {
                            Text(value)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(size == value ? Color.black : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    size == value
                                        ? AnyShapeStyle(GlassPalette.accentGradient)
                                        : AnyShapeStyle(Color.white.opacity(0.06)),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .glassSurface(radius: 24)
    }

    private var generatingCard: some View {
        HStack(spacing: 14) {
            ProgressView().tint(Palette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Генерирую изображение…")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("Обычно занимает 10–60 секунд.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .glassSurface(radius: 24)
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("История").font(.system(.headline, design: .rounded))
                Spacer()
                Text("\(store.generatedImages.count)").font(.caption).foregroundStyle(.secondary)
            }

            if store.generatedImages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Здесь появятся сгенерированные изображения.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 42)
                .glassSurface(radius: 24)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(store.generatedImages) { item in
                        imageCell(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func imageCell(_ item: GeneratedImage) -> some View {
        if let image = UIImage(data: item.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text(item.model)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onTapGesture { selected = item }
                .contextMenu {
                    Button { Task { @MainActor in await save(item) } } label: {
                        Label("Сохранить в Фото", systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) { store.deleteGeneratedImage(item.id) } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(.subheadline, design: .monospaced)).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func prepare() {
        if providerID == nil { providerID = store.activeProvider?.id ?? store.providers.first?.id }
        let candidates = imageModels
        if model.isEmpty || !candidates.contains(where: { $0.id == model }) {
            model = candidates.first(where: { $0.id == store.imageModel })?.id ?? candidates.first?.id ?? ""
        }
        size = store.imageSize
    }

    private func generate() {
        guard let provider, canGenerate else { return }
        focused = false
        store.generateImage(prompt: prompt, model: model, size: size, provider: provider)
    }

    private func save(_ item: GeneratedImage) async {
        do {
            try await PhotoSaver.save(item.data)
            notice = "Изображение сохранено в Фото."
        } catch {
            notice = error.localizedDescription
        }
    }
}

struct ImagePreviewSheet: View {
    let image: GeneratedImage
    @Environment(\.dismiss) private var dismiss
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let uiImage = UIImage(data: image.data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                    }
                } else {
                    Text("Не удалось открыть изображение").foregroundStyle(.white)
                }
            }
            .navigationTitle(image.model)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { @MainActor in await save() } } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .alert(
                "Уведомление",
                isPresented: Binding(
                    get: { notice != nil },
                    set: { if !$0 { notice = nil } }
                )
            ) {
                Button("OK") { notice = nil }
            } message: {
                Text(notice ?? "")
            }
        }
    }

    private func save() async {
        do {
            try await PhotoSaver.save(image.data)
            notice = "Изображение сохранено в Фото."
        } catch {
            notice = error.localizedDescription
        }
    }
}

enum PhotoSaver {
    static func save(_ data: Data) async throws {
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "Photos", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось декодировать изображение."])
        }
        let status: PHAuthorizationStatus = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "Photos", code: 2, userInfo: [NSLocalizedDescriptionKey: "Нет доступа к Фото. Разреши его в настройках iOS."])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Photos", code: 3, userInfo: [NSLocalizedDescriptionKey: "Не удалось сохранить изображение."]))
                }
            }
        }
    }
}
