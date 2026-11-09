import SwiftUI
import Combine

// MARK: - Palette: neutral & adaptive (semantic colors only).
enum GlassPalette {
    static let accent = Color.primary
    static let accent2 = Color.secondary
    static let violet = Color.secondary
    static let cyan = Color.primary
    static let mint = Color.secondary
}

// MARK: - Ambient screen background. Everything else renders on top of it
// WITHOUT plates: text and SF Symbols directly on the background, while the
// navigation bar / toolbar keep the stock iOS 26 Liquid Glass appearance.
struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
            Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.035))
                .frame(width: 380 * AppScale.k, height: 380 * AppScale.k).blur(radius: 100)
                .offset(x: drift ? 120 : -140, y: drift ? -260 : -160)
            Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.035 : 0.03))
                .frame(width: 300 * AppScale.k, height: 300 * AppScale.k).blur(radius: 110)
                .offset(x: drift ? -140 : 160, y: drift ? 300 : 220)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

extension View {
    /// Lets the system Liquid Glass (navigation bar, toolbar, controls) merge
    /// and refract properly on iOS 26+.
    @ViewBuilder
    func glassContainer() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer { self }
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Real system Liquid Glass capsule (iOS 26+). Falls back to a plain
    /// material on older systems.
    @ViewBuilder
    func glassCapsule(tint: Color = .clear) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
        #else
        self.background(.ultraThinMaterial, in: Capsule())
        #endif
    }

    /// Composer glass: fully transparent system glass (no gray fill), so it
    /// looks identical over a black chat background and over colorful photos.
    @ViewBuilder
    func composerGlass(radius: CGFloat = 24) -> some View {
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

    /// Real system Liquid Glass rounded rectangle.
    @ViewBuilder
    func glassSurface(radius: CGFloat = 22, tint: Color = .clear) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        #else
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        #endif
    }

    /// Circular glass button (Telegram / iOS 26 style).
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
}

// MARK: - Buttons: system glass capsule, prominent = tinted lens.
struct GlassButtonStyle: ButtonStyle {
    var prominent = false
    @ScaledMetric(relativeTo: .body) private var hPad: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var vPad: CGFloat = 12
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .frame(maxWidth: prominent ? .infinity : nil)
            .glassCapsule(tint: prominent ? Color.primary.opacity(0.12) : .clear)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct TypingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()
    @ScaledMetric(relativeTo: .body) private var dot: CGFloat = 6
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle().fill(Color.primary).frame(width: dot, height: dot)
                    .opacity(phase == index ? 1 : 0.25)
                    .scaleEffect(phase == index ? 1.15 : 0.85)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

struct VisionBadge: View {
    var compact = false
    var body: some View {
        Label(compact ? "фото" : "видит фото", systemImage: "camera.viewfinder")
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(.secondary)
    }
}
