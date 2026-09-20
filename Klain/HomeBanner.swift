import SwiftUI

struct HomeBanner: View {
    var body: some View {
        Link(destination: URL(string: "https://cheapvibecode.ru/ref/FJEU3K8DC9")!) {
            HStack(spacing: 12) {
                Image("AdLogo").resizable().scaledToFit().frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Реклама • партнёрская ссылка").font(.caption2).foregroundStyle(.secondary)
                    Text("CheapVibeCode").font(.headline)
                    Text("Дешёвые токены для 30+ ИИ-моделей").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
            }.padding(.vertical, 6)
        }
    }
}

struct SigningReminder: View {
    @AppStorage("signingReminderStart") private var start: Double = 0
    @State private var confirmReset = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = max(0, Int(ceil((start + 7 * 86400 - context.date.timeIntervalSince1970) / 86400)))
            VStack(alignment: .leading, spacing: 7) {
                Label(days == 0 ? "Обновите подпись приложения" : "Переустановите приложение через \(days) дн.", systemImage: "clock")
                    .font(.subheadline)
                Text("Напоминание для 7-дневной подписи SideStore/Sideloadly. Отсчёт от первого запуска или ручного сброса, не фактический срок сертификата. Можно обновить подпись без удаления приложения.")
                    .font(.caption2).foregroundStyle(.secondary)
                Button("Я обновил подпись") { confirmReset = true }.font(.caption)
            }
        }.onAppear { if start == 0 { start = Date().timeIntervalSince1970 } }
            .confirmationDialog("Начать новый отсчёт на 7 дней?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Начать отсчёт") { start = Date().timeIntervalSince1970 }
                Button("Отмена", role: .cancel) {}
            }
    }
}
