import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var balances: [UUID: String] = [:]
    @State private var loading = false

    private var input: Int { store.records.reduce(0) { $0 + ($1.usage.input ?? 0) } }
    private var output: Int { store.records.reduce(0) { $0 + ($1.usage.output ?? 0) } }
    private var cost: Double { store.records.reduce(0) { $0 + ($1.usage.cost ?? 0) } }
    private var hasCost: Bool { store.records.contains { $0.usage.cost != nil } }

    private struct ModelGroup: Identifiable {
        var id: String { key }
        var key: String
        var provider: String
        var model: String
        var title: String
        var input: Int
        var output: Int
        var count: Int
    }

    private struct ChatGroup: Identifiable {
        var id: UUID
        var title: String
        var model: String
        var input: Int
        var output: Int
        var count: Int
        var total: Int { input + output }
    }

    private var modelGroups: [ModelGroup] {
        let grouped = Dictionary(grouping: store.records, by: { "\($0.providerName)\u{1F}\($0.model)" })
        return grouped.map { key, records in
            let parts = key.components(separatedBy: "\u{1F}")
            let providerName = parts.first ?? ""
            let model = parts.count > 1 ? parts[1] : ""
            return ModelGroup(
                key: key,
                provider: providerName,
                model: model,
                title: model,
                input: records.reduce(0) { $0 + ($1.usage.input ?? 0) },
                output: records.reduce(0) { $0 + ($1.usage.output ?? 0) },
                count: records.count
            )
        }.sorted { $0.input + $0.output > $1.input + $1.output }
    }

    private var chatGroups: [ChatGroup] {
        let grouped = Dictionary(grouping: store.records, by: \.chatID)
        return grouped.map { id, records in
            ChatGroup(
                id: id,
                title: records.last?.chatTitle ?? "Чат",
                model: records.last?.model ?? "",
                input: records.reduce(0) { $0 + ($1.usage.input ?? 0) },
                output: records.reduce(0) { $0 + ($1.usage.output ?? 0) },
                count: records.count
            )
        }.sorted { $0.total > $1.total }
    }

    private var tintCycle: [Color] { [GlassPalette.accent, GlassPalette.violet, GlassPalette.cyan, GlassPalette.mint, GlassPalette.accent2] }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        totals
                        modelsCard
                        chatsCard
                        limitsCard
                    }
                    .padding(.horizontal, 16 * AppScale.k)
                    .padding(.top, 8 * AppScale.k)
                    .padding(.bottom, 32 * AppScale.k)
                }
                .scrollIndicators(.hidden)
            }
            .glassContainer()
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .glassCapsule()
                }
            }
        }
        .tint(Color.primary)
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "chart.bar.xaxis", color: GlassPalette.accent, title: "Токены", subtitle: "Это устройство")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                metric(title: "Входящие", value: store.records.contains { $0.usage.input != nil } ? input.formatted() : "—", icon: "arrow.down.left", color: GlassPalette.cyan)
                metric(title: "Исходящие", value: store.records.contains { $0.usage.output != nil } ? output.formatted() : "—", icon: "arrow.up.right", color: GlassPalette.violet)
                metric(title: "Ответы", value: store.records.count.formatted(), icon: "text.bubble", color: GlassPalette.mint)
                metric(title: "Стоимость", value: hasCost ? String(format: "$%.5f", cost) : "—", icon: "dollarsign.circle", color: GlassPalette.accent2)
            }
            Text("Только usage от API. Старые и пропущенные ответы не оцениваются, кэш входит во входящие.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16 * AppScale.k)
    }

    private var modelsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "cpu", color: GlassPalette.violet, title: "По моделям", subtitle: "\(modelGroups.count.formatted()) шт.")
            if modelGroups.isEmpty {
                placeholder(icon: "cpu", title: "Пока нет данных", subtitle: "Отправь сообщение, чтобы собрать статистику по моделям.")
            } else {
                ForEach(Array(modelGroups.enumerated()), id: \.element.id) { index, group in
                    row(
                        color: tintCycle[index % tintCycle.count],
                        icon: "cpu",
                        title: group.title,
                        subtitle: group.provider,
                        input: group.input,
                        output: group.output,
                        count: group.count
                    )
                }
            }
        }
        .padding(16 * AppScale.k)
    }

    private var chatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "bubble.left.and.bubble.right", color: GlassPalette.cyan, title: "По чатам", subtitle: "\(chatGroups.count.formatted()) шт.")
            if chatGroups.isEmpty {
                placeholder(icon: "bubble.left.and.bubble.right", title: "Пока нет данных", subtitle: "Здесь появятся чаты с суммарными токенами.")
            } else {
                ForEach(Array(chatGroups.enumerated()), id: \.element.id) { index, group in
                    row(
                        color: tintCycle[index % tintCycle.count],
                        icon: "bubble.left.and.bubble.right",
                        title: group.title,
                        subtitle: group.model,
                        input: group.input,
                        output: group.output,
                        count: group.count
                    )
                }
            }
        }
        .padding(16 * AppScale.k)
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "creditcard", color: GlassPalette.mint, title: "Остаток и лимиты", subtitle: nil)
            if store.providers.isEmpty {
                placeholder(icon: "server.rack", title: "Нет провайдеров", subtitle: "Добавь провайдера в настройках.")
            } else {
                ForEach(Array(store.providers.enumerated()), id: \.element.id) { index, provider in
                    providerRow(provider, color: tintCycle[index % tintCycle.count])
                }
            }
            Button {
                refreshBalances()
            } label: {
                HStack(spacing: 8) {
                    if loading { ProgressView().tint(.primary).scaleEffect(0.8) }
                    Image(systemName: "arrow.clockwise")
                    Text("Обновить баланс")
                }
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(loading)
            .frame(maxWidth: .infinity)
            Text("Rate limit — временный лимит запросов, а не купленные токены. Баланс доступен не для всех провайдеров.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16 * AppScale.k)
    }

    private func cardHeader(icon: String, color: Color, title: String, subtitle: String?) -> some View {
        HStack(spacing: 10) {
            iconCircle(icon, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func iconCircle(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14 * AppScale.k, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 30 * AppScale.k, height: 30 * AppScale.k)
            // Translucent glass instead of an opaque white circle (fixes the
            // white-on-white icon bug on the dark theme).
    }

    private func metric(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11 * AppScale.k, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 11 * AppScale.k, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22 * AppScale.k, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12 * AppScale.k)
    }

    private func row(color: Color, icon: String, title: String, subtitle: String, input: Int, output: Int, count: Int) -> some View {
        HStack(spacing: 12) {
            iconCircle(icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.isEmpty ? "Без названия" : title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle.isEmpty ? "—" : subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 8) {
                    Text("↑ \(input.formatted())")
                        .foregroundStyle(GlassPalette.cyan)
                    Text("↓ \(output.formatted())")
                        .foregroundStyle(GlassPalette.violet)
                }
                .font(.system(size: 12 * AppScale.k, weight: .semibold, design: .monospaced))
                Text("\(count) ответов")
                    .font(.system(size: 10 * AppScale.k, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12 * AppScale.k)
    }

    private func providerRow(_ provider: Provider, color: Color) -> some View {
        HStack(spacing: 12) {
            iconCircle("server.rack", color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(store.remaining[provider.id] ?? "Остаток токенов: нет данных")
                    .font(.system(size: 11 * AppScale.k, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(balances[provider.id] ?? "не запрошен")
                .font(.system(size: 11 * AppScale.k, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(12 * AppScale.k)
    }

    private func placeholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26 * AppScale.k, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22 * AppScale.k)
    }

    private func refreshBalances() {
        loading = true
        Task {
            for provider in store.providers {
                do {
                    balances[provider.id] = try await APIClient().balance(provider: provider) + "\n" + Date().formatted()
                } catch {
                    balances[provider.id] = error.localizedDescription
                }
            }
            loading = false
        }
    }
}
