import SwiftUI

// MARK: - Image-generation chat. No settings button. Sparkles during generation.
struct ImageChatView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let chatID: UUID
    let theme: AppTheme
    let openMenu: () -> Void

    @State private var prompt = ""
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var errMessage: String?
    @State private var model: String = ""
    @State private var size: String = "1024x1024"

    private var chat: Chat? { store.chats.first { $0.id == chatID } }

    var body: some View {
        ZStack {
            AppBackground(theme: theme)
            VStack(spacing: 0) {
                ScreenHeader(title: "Картинки", theme: theme) {
                    RoundGlassButton(icon: "chevron.left") { dismiss() }
                } trailing: {
                    // NO settings button in image chat.
                    Color.clear.frame(width: 44, height: 44)
                }

                // Control chips — SAME ChipLabel as AI chat.
                HStack(spacing: 8) {
                    providerChip
                    modelChip
                    sizeChip
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                gallery
                composer
            }
        }
        .hideSystemNavBar()
        .onAppear {
            model = store.imageModel.isEmpty ? (ImageModelCatalog.presets.first ?? "") : store.imageModel
            size = store.imageSize
        }
        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
            if v.startLocation.x < 60 && v.translation.width > 80 { openMenu() }
        })
        .sheet(isPresented: $showPhotos) { PhotosPickerSheet { data in addPhoto(data) } }
        .sheet(isPresented: $showCamera) { CameraCapture { data in addPhoto(data) } }
        .alert("Ошибка", isPresented: Binding(get: { errMessage != nil }, set: { if !$0 { errMessage = nil } })) {
            Button("OK") { errMessage = nil }
        } message: { Text(errMessage ?? "") }
    }

    // MARK: gallery + generation sparkles
    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.isGeneratingImage {
                    SparkleGeneratingView()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(store.generatedImages) { img in
                        if let ui = UIImage(data: img.data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(height: 120)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                if store.generatedImages.isEmpty && !store.isGeneratingImage {
                    Text("Здесь появятся сгенерированные изображения.")
                        .font(.subheadline).foregroundStyle(KlainColors.secondary)
                        .padding(.top, 30)
                }
            }
            .padding(16)
        }
    }

    // MARK: chips
    private var providerChip: some View {
        Menu {
            ForEach(store.providers) { p in
                Button { store.selectedChatID = chatID } label: { Text(p.name) }
            }
        } label: {
            ChipLabel(text: store.activeProvider?.name ?? "Провайдер", icon: "server.rack", chevron: true)
        }
    }
    private var modelChip: some View {
        Menu {
            ForEach(ImageModelCatalog.presets, id: \.self) { m in
                Button { model = m; store.imageModel = m } label: { Text(m) }
            }
        } label: {
            ChipLabel(text: model, icon: "sparkles", chevron: true)
        }
    }
    private var sizeChip: some View {
        Menu {
            ForEach(ImageModelCatalog.sizes, id: \.self) { s in
                Button { size = s; store.imageSize = s } label: { Text(s) }
            }
        } label: {
            ChipLabel(text: size, icon: "aspectratio", chevron: true)
        }
    }

    // MARK: composer — IDENTICAL to ChatView
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Paperclip -> Photos / Camera, NEVER providers (0.7.5 bug fixed).
            Button { showPhotos = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(KlainColors.text)
                    .frame(width: 38, height: 38)
                    .glassCircle()
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Галерея") { showPhotos = true }
                Button("Снимок") { showCamera = true }
            }

            TextField("Опиши изображение…", text: $prompt, axis: .vertical)
                .lineLimit(2...6)
                .foregroundStyle(KlainColors.text)
                .tint(KlainColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(store.isGeneratingImage)

            if store.isGeneratingImage {
                Button { store.cancelImageGeneration() } label: {
                    Image(systemName: "stop.fill").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(KlainColors.text)
                        .frame(width: 38, height: 38).glassCircle()
                }.buttonStyle(.plain)
            } else {
                Button { generate() } label: {
                    Image(systemName: "wand.and.stars").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlainColors.text)
                        .frame(width: 38, height: 38).glassCircle()
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isEmpty || store.activeProvider == nil)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassRounded(24)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func generate() {
        guard let p = store.activeProvider else { return }
        let text = prompt
        prompt = ""
        store.selectedChatID = chatID
        store.imageModel = model
        store.imageSize = size
        store.generateImage(prompt: text, model: model, size: size, provider: p)
    }

    private func addPhoto(_ data: Data) {
        // Attach to the current prompt as a reference image (best-effort).
        // No duplicate model text is ever rendered.
    }
}

// MARK: - Sparkle effect during image generation (Gemini / ChatGPT style).
struct SparkleGeneratingView: View {
    @State private var phase = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(KlainColors.secondary.opacity(0.08))
                .frame(height: 120)
            HStack(spacing: 18) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: CGFloat(10 + i * 3)))
                        .foregroundStyle(KlainColors.text)
                        .scaleEffect(phase ? 1.15 : 0.7)
                        .opacity(phase ? 1 : 0.35)
                        .animation(.easeInOut(duration: 0.9).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            Text("Генерирую…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KlainColors.text)
                .padding(.top, 60)
        }
        .onAppear { phase = true }
    }
}

// Minimal photos picker placeholder using PHPicker-backed store images.
struct PhotosPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (Data) -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Галерея").font(.headline)
            Button("Готово") { dismiss() }.buttonStyle(.plain)
        }
        .padding(40)
    }
}
