import SwiftUI

struct SettingsScreen: View {
    var openImages: () -> Void
    @State private var providers = false
    @State private var stats = false

    struct Row: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let tint: Color
        let url: String?
        let action: (() -> Void)?
    }

    private var settingsRows: [Row] {
        [
            Row(title: "Провайдеры", symbol: "slider.horizontal.3", tint: GlassPalette.accent, url: nil, action: { providers = true }),
            Row(title: "Статистика", symbol: "chart.bar.xaxis", tint: GlassPalette.cyan, url: nil, action: { stats = true }),
            Row(title: "Картинки", symbol: "sparkles", tint: GlassPalette.violet, url: nil, action: openImages)
        ]
    }

    private var authorRows: [Row] {
        [
            Row(title: "GitHub · miiko3", symbol: "chevron.left.forwardslash.chevron.right", tint: GlassPalette.accent, url: "https://github.com/miiko3", action: nil),
            Row(title: "Threads · @klain_app", symbol: "at", tint: GlassPalette.accent2, url: "https://www.threads.com/@klain_app", action: nil),
            Row(title: "Telegram · @yetilov", symbol: "paperplane.fill", tint: GlassPalette.cyan, url: "https://t.me/yetilov", action: nil),
            Row(title: "Boosty · поддержать", symbol: "heart.fill", tint: GlassPalette.mint, url: "https://boosty.to/miilo3", action: nil)
        ]
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card(title: "НАСТРОЙКИ", tint: GlassPalette.accent) {
                        VStack(spacing: 10) {
                            ForEach(settingsRows) { row in
                                SettingsRowView(row: row)
                            }
                        }
                    }
                    card(title: "АВТОР", tint: GlassPalette.accent2) {
                        VStack(spacing: 10) {
                            ForEach(authorRows) { row in
                                SettingsRowView(row: row)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("klain — песочница для запросов к ИИ по твоим API-ключам. Генерация изображений доступна, если её поддерживает провайдер и выбранная модель.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassSurface(radius: 22, tint: GlassPalette.violet)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $providers) { ProvidersView() }
        .sheet(isPresented: $stats) { StatisticsView() }
    }

    private func card<Content: View>(title: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(radius: 22, tint: tint)
    }
}

private struct SettingsRowView: View {
    let row: SettingsScreen.Row

    var body: some View {
        if let url = row.url, let destination = URL(string: url) {
            Link(destination: destination) { label }
                .buttonStyle(.plain)
        } else if let action = row.action {
            Button(action: action) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(row.tint)
                .frame(width: 30, height: 30)
                .background(row.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(row.title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
