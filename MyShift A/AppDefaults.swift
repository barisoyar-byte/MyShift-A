import Foundation

// Registers app-wide defaults early in app lifecycle.
// Ensure this file is compiled in the main app target.
struct AppDefaults {
    static func register() {
        UserDefaults.standard.register(defaults: [
            "selectedTeamIndex": 0
        ])
    }
}
