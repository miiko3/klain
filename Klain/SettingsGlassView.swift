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
            Row(title: "Telegram · @yetilov", symbol: "paperplane", tint: GlassPalette.cyan, url: "https://t.me/yetilov", action: nil),
            Row(title: "Boosty · поддержать", symbol: "heart", tint: GlassPalette.mint, url: "https://boosty.to/miilo3", action: nil)
        ]
    }

    @AppStorage(KlainTheme.storageKey) private var scheme: String = "dark"
    @AppStorage("klain.uiScale") private var uiScale: String = "normal"

    var body: some View {
        ZStack {
            LiquidBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card(title: "НАСТРОЙКИ", tint: GlassPalette.accent) {
                        VStack(spacing: 10) {
                            Picker("Тема", selection: $scheme) {
                                Text("Чёрная").tag("dark")
                                Text("Белая").tag("light")
                            }
                            .pickerStyle(.segmented)
                            Picker("Масштаб", selection: $uiScale) {
                                Text("Маленький").tag("small")
                                Text("Обычный").tag("normal")
                                Text("Крупный").tag("large")
                                Text("Очень крупный").tag("xlarge")
                            }
                            .pickerStyle(.segmented)
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
                    .padding(16 * AppScale.k)
                    .glassSurface(radius: 22, tint: GlassPalette.violet)
                }
                .padding(.horizontal, 18 * AppScale.k)
                .padding(.vertical, 16 * AppScale.k)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $providers) { ProvidersView() }
        .sheet(isPresented: $stats) { StatisticsView() }
    }

    private func card<Content: View>(title: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4 * AppScale.k)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14 * AppScale.k)
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
                .font(.system(size: 15 * AppScale.k, weight: .semibold))
                .foregroundStyle(row.tint)
                .frame(width: 30 * AppScale.k, height: 30 * AppScale.k)
                .background(row.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10 * AppScale.k, style: .continuous))
            Text(row.title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12 * AppScale.k, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12 * AppScale.k)
        .padding(.vertical, 10 * AppScale.k)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16 * AppScale.k, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16 * AppScale.k, style: .continuous))
    }
}
