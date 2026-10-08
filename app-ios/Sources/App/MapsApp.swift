import SwiftUI

@main
struct PrivateMapsApp: App {
    init() {
        BridgeEndpoint.applyDevelopmentSelection()
    }

    var body: some Scene {
        WindowGroup {
            MapScreen()
                .frame(minWidth: 360, minHeight: 500)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 800)
        #endif
    }
}
