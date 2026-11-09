import SwiftUI

// Global UI scale multiplier. Read straight from UserDefaults so every fixed
// size (.system(size:), .frame, .padding, cornerRadius) scales TOGETHER with
// the text — not only Dynamic Type fonts. KlainApp forces a rebuild on change.
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
                // Rebuild the whole tree so AppScale.k (fixed sizes) re-applies.
                .id("\(scheme)-\(uiScale)")
        }
    }
}

// Shared theme binding so Settings can toggle it from anywhere.
enum KlainTheme {
    static let storageKey = "klain.colorScheme"
}
