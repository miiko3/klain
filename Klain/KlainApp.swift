import SwiftUI

@main
struct KlainApp: App {
    @StateObject private var store = ChatStore()
    // Real black / white theme switch + UI scale, persisted, applied app-wide.
    @AppStorage("klain.colorScheme") private var scheme: String = "dark"
    @AppStorage("klain.uiScale") private var uiScale: String = "normal"

    private var typeSize: DynamicTypeSize {
        switch uiScale {
        case "small": return .small
        case "large": return .xLarge
        case "xlarge": return .xxxLarge
        default: return .medium
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .dynamicTypeSize(typeSize)
                .preferredColorScheme(scheme == "light" ? .light : .dark)
        }
    }
}

// Shared theme binding so Settings can toggle it from anywhere.
enum KlainTheme {
    static let storageKey = "klain.colorScheme"
}
