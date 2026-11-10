import SwiftUI

// Global UI scale (kept for the surviving views that still reference it).
enum AppScale {
    static var k: CGFloat {
        switch UserDefaults.standard.string(forKey: "klain.uiScale") ?? "normal" {
        case "small": return 0.85
        case "large": return 1.18
        case "xlarge": return 1.35
        default: return 1
        }
    }
}

// MARK: - App theme: black / white / winter (snow behind chats and menu).
enum AppTheme: String, CaseIterable, Identifiable {
    case dark, light, winter
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark: return "Чёрная"
        case .light: return "Белая"
        case .winter: return "Зимняя"
        }
    }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
}

// Semantic colors — the ONLY colors used by the UI.
enum KlainColors {
    static let text = Color.primary
    static let secondary = Color.secondary
    static let tertiary = Color.secondary.opacity(0.6)
    static let accent = Color.primary

    static func background(_ theme: AppTheme) -> some View {
        Group {
            switch theme {
            case .dark: Color.black
            case .light: Color.white
            case .winter:
                LinearGradient(colors: [
                    Color(red: 0.86, green: 0.91, blue: 0.97),
                    Color(red: 0.95, green: 0.97, blue: 1.0)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Winter snowfall (visible behind chats and the side menu).
struct Snowfall: View {
    @State private var animate = false
    private struct Flake: Identifiable {
        let id = UUID()
        var x: CGFloat, y: CGFloat, size: CGFloat, delay: Double, duration: Double, opacity: Double
    }
    private let flakes: [Flake] = (0..<36).map { i in
        Flake(
            x: CGFloat((i * 37) % 100) / 100,
            y: CGFloat((i * 53) % 100) / 100,
            size: CGFloat(3 + (i % 5)),
            delay: Double(i % 10) * 0.35,
            duration: Double(6 + (i % 7)),
            opacity: 0.25 + Double(i % 4) * 0.15
        )
    }
    var body: some View {
        GeometryReader { geo in
            ForEach(flakes) { f in
                Circle()
                    .fill(.white)
                    .frame(width: f.size, height: f.size)
                    .opacity(f.opacity)
                    .position(x: f.x * geo.size.width,
                              y: animate ? geo.size.height + 20 : -20)
                    .animation(
                        .linear(duration: f.duration)
                            .repeatForever(autoreverses: false)
                            .delay(f.delay),
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

// MARK: - App background: theme base + optional snow.
struct AppBackground: View {
    let theme: AppTheme
    var body: some View {
        ZStack {
            KlainColors.background(theme)
            if theme == .winter { Snowfall() }
        }
    }
}

// MARK: - Glass modifiers (system Liquid Glass, no hand-made gray plates).
extension View {
    @ViewBuilder
    func glassContainer() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { GlassEffectContainer { self } } else { self }
        #else
        self
        #endif
    }

    @ViewBuilder
    func glassCapsule() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
        #else
        self.background(.ultraThinMaterial, in: Capsule())
        #endif
    }

    @ViewBuilder
    func glassRounded(_ radius: CGFloat = 20) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        #else
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        #endif
    }

    @ViewBuilder
    func glassCircle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
        #else
        self.background(.ultraThinMaterial, in: Circle())
        #endif
    }

    /// Hide the system nav bar entirely; every screen draws its own header.
    func hideSystemNavBar() -> some View {
        if #available(iOS 18.0, *) {
            return AnyView(self.toolbar(.hidden, for: .navigationBar))
        } else {
            return AnyView(self.navigationBarHidden(true))
        }
    }
}

// MARK: - Unified header: round glass buttons + centered title capsule.
// No background plate of any kind.
struct ScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    let theme: AppTheme
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            leading()
            Spacer(minLength: 0)
            TitleCapsule(title: title)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

struct TitleCapsule: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(KlainColors.text)
            .lineLimit(1)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .glassCapsule()
    }
}

// Round glass icon button — ONE size everywhere.
struct RoundGlassButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KlainColors.text)
                .frame(width: 44, height: 44)
                .glassCircle()
        }
        .buttonStyle(.plain)
    }
}

// Text glass button (Готово / Назад / Сохранить) — SAME size as title.
struct TextGlassButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(KlainColors.text)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .glassCapsule()
        }
        .buttonStyle(.plain)
    }
}
