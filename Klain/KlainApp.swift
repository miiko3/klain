import SwiftUI

@main
struct KlainApp: App {
    @StateObject private var store = ChatStore()
    var body: some Scene { WindowGroup { ContentView().environmentObject(store) } }
}
