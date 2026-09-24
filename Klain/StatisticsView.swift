import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var balances: [UUID: String] = [:]
    @State private var loading = false
    private var input: Int { store.records.reduce(0) { $0 + ($1.usage.input ?? 0) } }
    private var output: Int { store.records.reduce(0) { $0 + ($1.usage.output ?? 0) } }
    private var groups: [String: [UsageRecord]] { Dictionary(grouping: store.records, by: { "\($0.providerName) / \($0.model)" }) }
    private var chats: [UUID: [UsageRecord]] { Dictionary(grouping: store.records, by: \.chatID) }
    var body: some View {
        NavigationStack {
            List {
                Section("ТОКЕНЫ • ЭТО УСТРОЙСТВО") {
                    LabeledContent("Входящие", value: store.records.contains { $0.usage.input != nil } ? input.formatted() : "Нет данных")
                    LabeledContent("Исходящие", value: store.records.contains { $0.usage.output != nil } ? output.formatted() : "Нет данных")
                    LabeledContent("Учтено ответов", value: store.records.count.formatted())
                    if store.records.contains(where: { $0.usage.cost != nil }) { LabeledContent("Стоимость, сообщённая API", value: String(format: "$%.5f", store.records.reduce(0) { $0 + ($1.usage.cost ?? 0) })) }
                    Text("Только usage, полученный от API. Пропущенные и старые ответы не оцениваются. Стоимость может быть известна лишь для части запросов. Кэшированные токены входят во входящие.").font(.caption).foregroundStyle(.secondary)
                }
                Section("ПО МОДЕЛЯМ") { ForEach(groups.keys.sorted(), id: \.self) { key in usageRow(key, records: groups[key] ?? []) } }
                Section("ПО ЧАТАМ") { ForEach(chats.keys.sorted(by: { $0.uuidString < $1.uuidString }), id: \.self) { id in usageRow(chats[id]?.first?.chatTitle ?? "Чат", records: chats[id] ?? []) } }
                Section("ОСТАТОК И ЛИМИТЫ") {
                    ForEach(store.providers) { p in VStack(alignment: .leading, spacing: 8) { Text(p.name); Text(store.remaining[p.id] ?? "Остаток токенов: нет данных").font(.caption).foregroundStyle(.secondary); Text(balances[p.id] ?? "Баланс: не запрошен").font(.caption).foregroundStyle(.secondary) } }
                    Button("Обновить баланс") { loading = true; Task { for p in store.providers { do { balances[p.id] = try await APIClient().balance(provider: p) + "\n" + Date().formatted() } catch { balances[p.id] = error.localizedDescription } }; loading = false } }.disabled(loading)
                    if loading { ProgressView() }
                    Text("Rate limit — временный лимит запросов, а не купленные токены. Баланс доступен для OpenRouter и CheapVibeCode. Остальные значения показываются только при наличии в заголовках API.").font(.caption).foregroundStyle(.secondary)
                }
            }.scrollContentBackground(.hidden).background(Palette.background).navigationTitle("Статистика").toolbar { Button("Готово") { dismiss() } }
        }.preferredColorScheme(.dark).tint(Palette.accent)
    }
    private func usageRow(_ title: String, records: [UsageRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.subheadline); Text("↑ \(records.reduce(0) { $0 + ($1.usage.input ?? 0) })  ↓ \(records.reduce(0) { $0 + ($1.usage.output ?? 0) }) • \(records.count) ответов").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.accent) }
    }
}
