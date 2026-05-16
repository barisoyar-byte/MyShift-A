import SwiftUI

@main
struct MyShiftApp: App {
    init() {
        // App launch sırasında ekip.json'u UserDefaults'a yükle
        initializeEkipFromBundleIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            MenuView()
        }
    }
}
