import AppKit
import AVFoundation
import os

private let logger = Logger(subsystem: "com.voiceflow.app", category: "PermissionManager")

final class PermissionManager {
    static let shared = PermissionManager()

    enum PermissionType {
        case accessibility
        case microphone
    }

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case restricted
    }

    struct AllPermissionsStatus {
        let isAccessibilityGranted: Bool
        let isMicrophoneGranted: Bool
        let accessibilityState: PermissionStatus
        let microphoneState: PermissionStatus
    }

    private init() {}

    /// Check Accessibility permission status
    func checkAccessibilityPermission() -> PermissionStatus {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        let status: PermissionStatus = accessibilityEnabled ? .granted : .denied
        NSLog("[PermissionManager] Accessibility permission: %@", accessibilityEnabled ? "granted" : "denied")

        return status
    }

    /// Check Microphone permission status
    func checkMicrophonePermission() -> PermissionStatus {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        let status: PermissionStatus
        switch authStatus {
        case .authorized:
            status = .granted
            NSLog("[PermissionManager] Microphone permission: granted")
        case .denied:
            status = .denied
            NSLog("[PermissionManager] Microphone permission: denied")
        case .notDetermined:
            status = .notDetermined
            NSLog("[PermissionManager] Microphone permission: not determined")
        case .restricted:
            status = .restricted
            NSLog("[PermissionManager] Microphone permission: restricted")
        @unknown default:
            status = .denied
            NSLog("[PermissionManager] Microphone permission: unknown status")
        }

        return status
    }

    /// Check all permissions and return combined status
    func checkAllPermissions() -> AllPermissionsStatus {
        let accessibilityState = checkAccessibilityPermission()
        let microphoneState = checkMicrophonePermission()

        return AllPermissionsStatus(
            isAccessibilityGranted: accessibilityState == .granted,
            isMicrophoneGranted: microphoneState == .granted,
            accessibilityState: accessibilityState,
            microphoneState: microphoneState
        )
    }

    /// Open System Settings to the appropriate permission pane
    func openSystemSettings(for type: PermissionType) {
        let urlString: String

        switch type {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            NSLog("[PermissionManager] Opening System Settings for Accessibility")
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            NSLog("[PermissionManager] Opening System Settings for Microphone")
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            NSLog("[PermissionManager] Failed to create URL for System Settings")
        }
    }
}
