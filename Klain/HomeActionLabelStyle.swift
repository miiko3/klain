import SwiftUI

struct HomeActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 7) {
            configuration.icon.font(.system(size: 23))
            configuration.title.lineLimit(1).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity, minHeight: 64).contentShape(Rectangle())
    }
}
