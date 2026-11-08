import SwiftUI
import Combine

enum GlassPalette {
    static let accent = Color(red: 0.99, green: 0.60, blue: 0.36)
    static let accent2 = Color(red: 0.93, green: 0.35, blue: 0.63)
    static let violet = Color(red: 0.48, green: 0.38, blue: 0.99)
    static let cyan = Color(red: 0.22, green: 0.74, blue: 0.94)
    static let mint = Color(red: 0.36, green: 0.88, blue: 0.72)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var coolGradient: LinearGradient {
        LinearGradient(colors: [violet, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Liquid background (iOS 26/27: layered, animated, adaptive)
struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            (colorScheme == .dark
                ? Color(red: 0.045, green: 0.045, blue: 0.08)
                : Color(red: 0.96, green: 0.96, blue: 0.99))

            LinearGradient(
                colors: [
                    GlassPalette.accent.opacity(colorScheme == .dark ? 0.20 : 0.16),
                    GlassPalette.violet.opacity(colorScheme == .dark ? 0.26 : 0.15),
                    GlassPalette.cyan.opacity(colorScheme == .dark ? 0.16 : 0.12)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle().fill(GlassPalette.accent.opacity(colorScheme == .dark ? 0.30 : 0.20))
                .frame(width: 330, height: 330).blur(radius: 100)
                .offset(x: drift ? 140 : -150, y: drift ? -270 : -170)
            Circle().fill(GlassPalette.violet.opacity(colorScheme == .dark ? 0.34 : 0.22))
                .frame(width: 300, height: 300).blur(radius: 110)
                .offset(x: drift ? -160 : 150, y: drift ? 280 : 210)
            Circle().fill(GlassPalette.cyan.opacity(colorScheme == .dark ? 0.22 : 0.16))
                .frame(width: 250, height: 250).blur(radius: 95)
                .offset(x: drift ? 50 : -70, y: drift ? 60 : -40)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Liquid Glass surface (iOS 26/27 look on every supported OS)
struct GlassSurface: ViewModifier {
    @ScaledMetric(relativeTo: .body) var radius: CGFloat = 22
    var tint: Color = .clear
    var interactive = true

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Adaptive tint sampled from the ambient accent, not a flat wash.
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [tint == .clear ? GlassPalette.accent.opacity(0.06) : tint.opacity(0.16),
                                                         GlassPalette.violet.opacity(0.05)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    // Specular rim: light catching edges + inner caustic.
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.72), .white.opacity(0.06),
                                                        .white.opacity(0.30), .white.opacity(0.62)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.white.opacity(0.18)).frame(height: 1).padding(.horizontal, radius / 2)
                    }
            }
            .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 11)
            .shadow(color: GlassPalette.accent.opacity(0.06), radius: 18, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    @ViewBuilder
    func glassSurface(radius: CGFloat = 22, tint: Color = .clear) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint == .clear ? GlassPalette.accent.opacity(0.06) : tint.opacity(0.20)).interactive(),
                             in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 10)
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
            self.glassEffect(.regular.tint(tint == .clear ? .clear : tint.opacity(0.20)).interactive(), in: Capsule())
        } else {
            glassCapsuleFallback()
        }
        #else
        glassCapsuleFallback()
        #endif
    }

    func glassCapsuleFallback() -> some View {
        self.background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10), .white.opacity(0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

struct GlassButtonStyle: ButtonStyle {
    var prominent = false
    @ScaledMetric(relativeTo: .body) private var hPad: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var vPad: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(prominent ? Color.black : Color.primary)
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .frame(maxWidth: prominent ? .infinity : nil)
            .background {
                if prominent { Capsule().fill(GlassPalette.accentGradient) }
                else { Capsule().fill(.ultraThinMaterial) }
            }
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(colors: [.white.opacity(prominent ? 0.45 : 0.55), .white.opacity(0.08), .white.opacity(0.35)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: GlassPalette.accent.opacity(prominent ? 0.34 : 0), radius: 16, x: 0, y: 8)
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
            .foregroundStyle(tint)
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
                Circle().fill(Palette.accent).frame(width: dot, height: dot)
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
            .foregroundStyle(Color.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(GlassPalette.coolGradient, in: Capsule())
    }
}
