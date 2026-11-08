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

    private var displayName: String {
        imageModels.first(where: { $0.id == model })?.name ?? (model.isEmpty ? "Модель не выбрана" : model)
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        hero
                        if !store.isGeneratingImage && store.generatedImages.isEmpty { emptyGallery }
                        card { gallery }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 210)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) { composer }
                .onChange(of: store.isGeneratingImage) { _, active in
                    if active { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("composer", anchor: .bottom) } }
                }
            }
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
        .fullScreenCover(item: $selected) { item in
            ImagePreviewSheet(image: item)
        }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(store.providers.isEmpty ? Color.orange : GlassPalette.mint)
                    .frame(width: 7, height: 7)
                Text(store.providers.isEmpty ? "API не настроен" : "API подключён")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("Image Studio")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            Text("Опиши идею — модель нарисует её.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    private var emptyGallery: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Здесь появятся сгенерированные изображения.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .glassSurface(radius: 24)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .glassSurface(radius: 22)
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("История").font(.system(.headline, design: .rounded))
                Spacer()
                Text("\(store.generatedImages.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.generatedImages.isEmpty {
                Text("Пока пусто")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
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
                .frame(height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text(item.model)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.35), in: Capsule())
                        .padding(6)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isGeneratingImage {
                generatingRow
            }

            if store.isGeneratingImage,
               let latestID = store.latestImageID,
               let latest = store.generatedImages.first(where: { $0.id == latestID }),
               let image = UIImage(data: latest.data) {
                Button { selected = latest } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.black.opacity(0.35), in: Circle())
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
            }

            TextField("Опиши изображение…", text: $prompt, axis: .vertical)
                .lineLimit(2...6)
                .focused($focused)

            if !store.providers.isEmpty {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(store.providers) { p in
                            Button { providerID = p.id } label: {
                                if provider?.id == p.id { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                            }
                        }
                    } label: {
                        chipLabel(systemImage: "server.rack", text: provider?.name ?? "Провайдер")
                    }

                    Menu {
                        ForEach(imageModels) { entry in
                            Button { chooseModel(entry.id) } label: {
                                if model == entry.id { Label(entry.name, systemImage: "checkmark") } else { Text(entry.name) }
                            }
                        }
                    } label: {
                        chipLabel(systemImage: "sparkles", text: displayName)
                    }

                    Menu {
                        ForEach(ImageModelCatalog.sizes, id: \.self) { value in
                            Button { size = value } label: {
                                if size == value { Label(value, systemImage: "checkmark") } else { Text(value) }
                            }
                        }
                    } label: {
                        chipLabel(systemImage: "aspectratio", text: size)
                    }
                }
            }

            HStack(spacing: 8) {
                if !prompt.isEmpty && !store.isGeneratingImage {
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
                    Button { store.cancelImageGeneration() } label: {
                        Label("Отменить", systemImage: "stop.fill")
                    }
                    .buttonStyle(GlassButtonStyle())
                } else {
                    Button { generate() } label: {
                        Label("Сгенерировать", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(GlassButtonStyle(prominent: true))
                    .disabled(!canGenerate)
                    .opacity(canGenerate ? 1 : 0.5)
                }
            }
        }
        .padding(14)
        .glassSurface(radius: 26)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .padding(.top, 6)
        .id("composer")
    }

    private var generatingRow: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Palette.accent).scaleEffect(0.85)
            VStack(alignment: .leading, spacing: 2) {
                Text("Генерирую…")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("Обычно 10–60 секунд")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chipLabel(systemImage: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            Text(text).lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassCapsule()
    }

    private func prepare() {
        if providerID == nil { providerID = store.activeProvider?.id ?? store.providers.first?.id }
        let candidates = imageModels
        if model.isEmpty || !candidates.contains(where: { $0.id == model }) {
            model = candidates.first(where: { $0.id == store.imageModel })?.id ?? candidates.first?.id ?? ""
        }
        size = store.imageSize
    }

    private func chooseModel(_ id: String) {
        model = id
        store.imageModel = id
    }

    private func generate() {
        guard let provider, canGenerate else { return }
        focused = false
        store.generateImage(prompt: prompt, model: model, size: size, provider: provider)
        prompt = ""
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
                    GeometryReader { geo in
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                } else {
                    Text("Не удалось открыть изображение").foregroundStyle(.white)
                }
            }
            .navigationTitle(image.model)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Material.ultraThinMaterial, for: .navigationBar)
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
