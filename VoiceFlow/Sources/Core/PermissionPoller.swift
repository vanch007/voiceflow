import Foundation

/// 权限轮询器：每秒检测权限状态，授权后自动回调
final class PermissionPoller {
    private var timer: Timer?

    func startPolling(for type: PermissionManager.PermissionType,
                      interval: TimeInterval = 1.0,
                      onGranted: @escaping () -> Void) {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            let granted: Bool
            switch type {
            case .accessibility:
                granted = PermissionManager.shared.checkAccessibilityPermission() == .granted
            case .microphone:
                granted = PermissionManager.shared.checkMicrophonePermission() == .granted
            }
            if granted {
                self?.stopPolling()
                DispatchQueue.main.async { onGranted() }
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
