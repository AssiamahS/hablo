import SwiftUI

@main
struct HabloApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .updateCheck(site: "https://assiamahs.github.io/hablo")
        }
    }
}
