import SwiftUI
import Combine

// MARK: - Palette: neutral, adaptive (semantic only, never a plate).
enum GlassPalette {
    static let accent = Color.primary
    static let accent2 = Color.secondary
    static let violet = Color.secondary
    static let cyan = Color.primary
    static let mint = Color.secondary

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [Color.primary, Color.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var coolGradient: LinearGradient {
        LinearGradient(colors: [Color.secondary.opacity(0.5), Color.primary.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Ambient screen background ONLY. No UI-element backplates anywhere.
struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
            Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
                .frame(width: 380 * AppScale.k, height: 380 * AppScale.k).blur(radius: 100)
                .offset(x: drift ? 120 : -140, y: drift ? -260 : -160)
            Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.03))
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

// MARK: - NO-OP glass modifiers.
// The design intentionally has zero backplates / borders / separators under
// any UI element. These helpers exist only so legacy call sites stay valid.
struct GlassSurface: ViewModifier {
    @ScaledMetric(relativeTo: .body) var radius: CGFloat = 22
    var tint: Color = .clear
    var interactive = true
    func body(content: Content) -> some View { content }
}

extension View {
    func glassContainer() -> some View { self }

    func glassSurface(radius: CGFloat = 22, tint: Color = .clear) -> some View { self }
    func glassCapsule(tint: Color = .clear) -> some View { self }
    func glassCapsuleFallback() -> some View { self }
    func capsuleGlass() -> some View { self }
    func glassRounded(_ radius: CGFloat = 16, style: RoundedCornerStyle = .continuous) -> some View { self }
    func glassCircle() -> some View { self }
}

// MARK: - Buttons: text only, no background.
struct GlassButtonStyle: ButtonStyle {
    var prominent = false
    @ScaledMetric(relativeTo: .body) private var hPad: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var vPad: CGFloat = 12
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(prominent ? Color.primary : Color.secondary)
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .frame(maxWidth: prominent ? .infinity : nil)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    var tint: Color = GlassPalette.accent
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 40
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
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
            .padding(.horizontal, 7 * AppScale.k).padding(.vertical, 3 * AppScale.k)
    }
}
