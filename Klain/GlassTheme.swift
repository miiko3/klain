import SwiftUI
import Combine

enum GlassPalette {
    static let accent = Color(red: 0.98, green: 0.55, blue: 0.32)
    static let accent2 = Color(red: 0.92, green: 0.36, blue: 0.62)
    static let violet = Color(red: 0.45, green: 0.36, blue: 0.98)
    static let cyan = Color(red: 0.22, green: 0.72, blue: 0.92)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct LiquidBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            Palette.background

            LinearGradient(
                colors: [
                    GlassPalette.accent.opacity(0.16),
                    GlassPalette.violet.opacity(0.25),
                    GlassPalette.cyan.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(GlassPalette.accent.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 96)
                .offset(x: drift ? 130 : -150, y: drift ? -260 : -170)

            Circle()
                .fill(GlassPalette.violet.opacity(0.30))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: drift ? -150 : 150, y: drift ? 260 : 210)

            Circle()
                .fill(GlassPalette.cyan.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: drift ? 40 : -60, y: drift ? 70 : -30)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
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
                            .fill(tint.opacity(0.12))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.48),
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 10)
    }
}

extension View {
    @ViewBuilder
    func glassSurface(radius: CGFloat = 22, tint: Color = .clear) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(
                    .regular.tint(tint.opacity(0.16)),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 9)
        } else {
            self.modifier(GlassSurface(radius: radius, tint: tint))
        }
        #else
        self.modifier(GlassSurface(radius: radius, tint: tint))
        #endif
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
            .shadow(color: GlassPalette.accent.opacity(prominent ? 0.30 : 0), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
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
