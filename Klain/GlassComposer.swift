import SwiftUI

// MARK: - Unified composer used by BOTH the AI chat and the Image Studio.
// One design, two screens: control chips float ABOVE the single glass block,
// the block holds the text field with round glass buttons on its edges.
struct GlassComposer<Controls: View, Field: View>: View {
    var radius: CGFloat = 24
    var placeholder: String
    var text: Binding<String>
    var isSending: Bool = false
    var sendEnabled: Bool = true
    var onSend: () -> Void
    var onStop: () -> Void
    var onAttach: () -> Void
    @ViewBuilder var controls: () -> Controls
    @ViewBuilder var field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * AppScale.k) {
            // Control chips: separate capsules floating above the input block.
            HStack(spacing: 8 * AppScale.k) {
                controls()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4 * AppScale.k)

            // The one and only glass block.
            HStack(alignment: .bottom, spacing: 10 * AppScale.k) {
                Button(action: onAttach) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 17 * AppScale.k, weight: .light))
                        .foregroundStyle(.primary)
                        .frame(width: 38 * AppScale.k, height: 38 * AppScale.k)
                        .glassCircle()
                }

                field()
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSending {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13 * AppScale.k, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 38 * AppScale.k, height: 38 * AppScale.k)
                            .glassCircle()
                    }
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16 * AppScale.k, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 38 * AppScale.k, height: 38 * AppScale.k)
                            .glassCircle()
                    }
                    .disabled(!sendEnabled)
                    .opacity(sendEnabled ? 1 : 0.4)
                }
            }
            .padding(.horizontal, 10 * AppScale.k)
            .padding(.vertical, 8 * AppScale.k)
            .glassSurface(radius: radius * AppScale.k)
        }
    }
}

// MARK: - Small glass chip used for model / reasoning / web / provider picks.
struct GlassChip<Label: View>: View {
    var icon: String?
    var tint: Color = .primary
    @ViewBuilder var label: () -> Label

    var body: some View {
        HStack(spacing: 5 * AppScale.k) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11 * AppScale.k, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            label()
        }
        .font(.system(size: 12 * AppScale.k, weight: .medium, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 12 * AppScale.k)
        .padding(.vertical, 8 * AppScale.k)
        .glassCapsule()
    }
}
