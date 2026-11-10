import SwiftUI

@main
struct KlainApp: App {
    @StateObject private var store = ChatStore()
    @AppStorage("klain.theme") private var themeRaw: String = AppTheme.dark.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .dark }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(theme.colorScheme)
                .id(themeRaw) // rebuild so AppBackground/snow re-apply
        }
    }
}

// Shared theme key (used by the side menu picker).
enum KlainThemeStorage {
    static let key = "klain.theme"
}
