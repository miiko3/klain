import SwiftUI
import Combine

// Monochrome palette. Every former accent hue maps to primary/gray so the
// whole app renders black-and-white in both color schemes without touching
// each call site. Gradients become subtle gray washes, never colored.
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
        LinearGradient(colors: [Color.secondary.opacity(0.6), Color.primary.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Ambient background: monochrome, subtle, real dark/light themes
struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)

            LinearGradient(
                colors: [
                    Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03),
                    Color.primary.opacity(colorScheme == .dark ? 0.02 : 0.015)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
                .frame(width: 330 * AppScale.k, height: 330 * AppScale.k).blur(radius: 110)
                .offset(x: drift ? 140 : -150, y: drift ? -270 : -170)
            Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
                .frame(width: 300 * AppScale.k, height: 300 * AppScale.k).blur(radius: 120)
                .offset(x: drift ? -160 : 150, y: drift ? 280 : 210)
            Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.03))
                .frame(width: 250 * AppScale.k, height: 250 * AppScale.k).blur(radius: 100)
                .offset(x: drift ? 50 : -70, y: drift ? 60 : -40)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Glass surface: pure blur + translucent material only.
// No borders, no specular rims, no shadows, no gradient tint overlays.
struct GlassSurface: ViewModifier {
    @ScaledMetric(relativeTo: .body) var radius: CGFloat = 22
    var tint: Color = .clear
    var interactive = true

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    @ViewBuilder
    func glassSurface(radius: CGFloat = 22, tint: Color = .clear) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self.modifier(GlassSurface(radius: radius, tint: tint))
        }
        #else
        self.modifier(GlassSurface(radius: radius, tint: tint))
        #endif
    }

    @ViewBuilder
    func glassCapsule(tint: Color = .clear) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            glassCapsuleFallback()
        }
        #else
        glassCapsuleFallback()
        #endif
    }

    func glassCapsuleFallback() -> some View {
        self.background(.ultraThinMaterial, in: Capsule())
    }
}

struct GlassButtonStyle: ButtonStyle {
    var prominent = false
    @ScaledMetric(relativeTo: .body) private var hPad: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var vPad: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .frame(maxWidth: prominent ? .infinity : nil)
            .background {
                if prominent { Capsule().fill(Color.primary.opacity(0.16)) }
                else { Capsule().fill(.ultraThinMaterial) }
            }
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
            .glassCapsule(tint: tint)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.7), value: configuration.isPressed)
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
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 7 * AppScale.k).padding(.vertical, 3 * AppScale.k)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
