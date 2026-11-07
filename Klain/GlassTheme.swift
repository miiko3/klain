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

struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

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
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(GlassPalette.accent.opacity(colorScheme == .dark ? 0.30 : 0.20))
                .frame(width: 330, height: 330)
                .blur(radius: 100)
                .offset(x: drift ? 140 : -150, y: drift ? -270 : -170)

            Circle()
                .fill(GlassPalette.violet.opacity(colorScheme == .dark ? 0.34 : 0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: drift ? -160 : 150, y: drift ? 280 : 210)

            Circle()
                .fill(GlassPalette.cyan.opacity(colorScheme == .dark ? 0.22 : 0.16))
                .frame(width: 250, height: 250)
                .blur(radius: 95)
                .offset(x: drift ? 50 : -70, y: drift ? 60 : -40)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 22
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint.opacity(0.16))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.50),
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 11)
    }
}

extension View {
    @ViewBuilder
    func glassSurface(radius: CGFloat = 22, tint: Color = .clear) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(
                    .regular.tint(tint.opacity(0.20)),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
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
            self.glassEffect(.regular.tint(tint.opacity(0.20)), in: Capsule())
        } else {
            glassCapsuleFallback()
        }
        #else
        glassCapsuleFallback()
        #endif
    }

    func glassCapsuleFallback() -> some View {
        self
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.30), lineWidth: 1))
    }
}

struct GlassButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(prominent ? Color.black : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: prominent ? CGFloat.infinity : nil)
            .background {
                if prominent {
                    Capsule().fill(GlassPalette.accentGradient)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(prominent ? 0.26 : 0.34), lineWidth: 1)
            }
            .shadow(color: GlassPalette.accent.opacity(prominent ? 0.34 : 0), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    var tint: Color = GlassPalette.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .glassCapsule(tint: tint)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct TypingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 6, height: 6)
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
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(GlassPalette.coolGradient, in: Capsule())
    }
}
