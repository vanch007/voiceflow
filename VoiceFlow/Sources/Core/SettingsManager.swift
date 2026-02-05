import Foundation
import Combine

/// Manages app-wide settings and preferences using UserDefaults persistence
class SettingsManager: ObservableObject {
    /// Tracks whether the user has completed the first-time onboarding wizard
    /// Defaults to false for first-launch detection
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    init() {
        // Load persisted value from UserDefaults (defaults to false if not set)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}
