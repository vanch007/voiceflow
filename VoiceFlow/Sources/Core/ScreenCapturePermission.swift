import Foundation
import ScreenCaptureKit

/// 屏幕录制权限管理器
/// 用于检查和请求 ScreenCaptureKit 权限（系统音频捕获需要此权限）
final class ScreenCapturePermission {
    static let shared = ScreenCapturePermission()

    private init() {}

    /// 权限状态
    enum Status {
        case authorized      // 已授权
        case denied          // 已拒绝
        case notDetermined   // 未确定
    }

    /// 检查屏幕录制权限状态
    /// - Returns: 权限状态
    func checkPermission() async -> Status {
        do {
            // 尝试获取可共享内容，这会触发权限检查
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            // 如果成功获取（没有抛出错误），说明已授权
            NSLog("[ScreenCapturePermission] 权限检查通过")
            return .authorized
        } catch let error as NSError {
            NSLog("[ScreenCapturePermission] 权限检查失败: domain=%@, code=%d, %@",
                  error.domain, error.code, error.localizedDescription)
            // SCStreamErrorCode: -3801 表示权限被拒绝
            if error.code == -3801 || error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" {
                return .denied
            }
            // 其他错误也视为拒绝（保守处理）
            return .denied
        }
    }

    /// 请求屏幕录制权限
    /// 这会触发系统权限对话框（如果尚未授权）
    /// - Returns: 是否授权成功
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            // 调用 SCShareableContent 会触发权限请求
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return !content.displays.isEmpty
        } catch {
            NSLog("[ScreenCapturePermission] 权限请求失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 打开系统偏好设置的屏幕录制权限页面
    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 检查权限并在被拒绝时显示提示
    /// - Parameter showAlert: 权限被拒绝时是否显示提示
    /// - Returns: 是否已授权
    func checkAndPrompt(showAlert: Bool = true) async -> Bool {
        let status = await checkPermission()

        switch status {
        case .authorized:
            return true
        case .denied:
            if showAlert {
                await showPermissionDeniedAlert()
            }
            return false
        case .notDetermined:
            // 首次请求权限
            return await requestPermission()
        }
    }

    /// 显示权限被拒绝的提示
    @MainActor
    private func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = "VoiceFlow 需要屏幕录制权限来捕获系统音频进行实时转录。\n\n请在系统设置中授予权限后重试。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemPreferences()
        }
    }
}
