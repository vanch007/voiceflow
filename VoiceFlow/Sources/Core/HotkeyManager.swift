import AppKit

extension Notification.Name {
    static let hotkeyConfigDidChange = Notification.Name("hotkeyConfigDidChange")
    static let systemAudioHotkeyConfigDidChange = Notification.Name("systemAudioHotkeyConfigDidChange")
}

final class HotkeyManager {
    var onLongPress: (() -> Void)?
    var onLongPressEnd: (() -> Void)?
    var onToggleRecording: (() -> Void)?  // 自由说话模式：切换录音状态
    var onSystemAudioDoubleTap: (() -> Void)?  // 系统音频录制切换

    private var currentConfig: HotkeyConfig
    private var systemAudioConfig: HotkeyConfig
    private var keyIsDown = false
    private var keyPressTime: TimeInterval = 0
    private var longPressTimer: Timer?
    private var monitor: Any?
    private var keyDownMonitor: Any?
    private var isEnabled = true
    private let userDefaultsKey = "voiceflow.hotkeyConfig"
    private let systemAudioUserDefaultsKey = "voiceflow.systemAudioHotkeyConfig"

    // Double-tap detection (for doubleTap trigger mode)
    private var lastTapTime: TimeInterval = 0
    private var tapCount = 0

    // System audio hotkey detection (可配置)
    private var sysAudioLastTapTime: TimeInterval = 0
    private var sysAudioTapCount = 0
    private var sysAudioKeyIsDown = false
    private var sysAudioKeyPressTime: TimeInterval = 0
    private var sysAudioLongPressTimer: Timer?

    init() {
        // Load config from UserDefaults or use default
        currentConfig = HotkeyManager.loadConfig()
        systemAudioConfig = HotkeyManager.loadSystemAudioConfig()

        // Listen for config changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigChange(_:)),
            name: .hotkeyConfigDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemAudioConfigChange(_:)),
            name: .systemAudioHotkeyConfigDidChange,
            object: nil
        )
    }

    @objc private func handleConfigChange(_ notification: Notification) {
        if let config = notification.userInfo?["config"] as? HotkeyConfig {
            updateConfig(config)
        } else {
            // Reload from UserDefaults
            currentConfig = HotkeyManager.loadConfig()
            NSLog("[HotkeyManager] Config reloaded: \(currentConfig.displayString)")
        }
    }

    @objc private func handleSystemAudioConfigChange(_ notification: Notification) {
        if let config = notification.userInfo?["config"] as? HotkeyConfig {
            systemAudioConfig = config
            NSLog("[HotkeyManager] System audio config updated to: \(config.displayString)")
        } else {
            systemAudioConfig = HotkeyManager.loadSystemAudioConfig()
            NSLog("[HotkeyManager] System audio config reloaded: \(systemAudioConfig.displayString)")
        }
    }

    func updateConfig(_ config: HotkeyConfig) {
        currentConfig = config
        NSLog("[HotkeyManager] Config updated to: \(config.displayString)")
    }

    func enable() {
        isEnabled = true
        NSLog("[HotkeyManager] Hotkey enabled")
    }

    func disable() {
        isEnabled = false
        NSLog("[HotkeyManager] Hotkey disabled")
    }

    func start() {
        // Check Accessibility permissions first
        let isTrusted = AXIsProcessTrusted()
        NSLog("[HotkeyManager] Accessibility permission status: \(isTrusted)")

        guard isTrusted else {
            NSLog("[HotkeyManager] FAILED to start: Accessibility permission not granted!")
            return
        }

        NSLog("[HotkeyManager] 正在创建事件监听器 (语音输入: \(currentConfig.displayString), 系统音频: \(systemAudioConfig.displayString))...")

        // Monitor for modifier key changes (for modifier-based triggers)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
        }

        // Monitor for key down events (for combination triggers with non-modifier keys)
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event: event)
        }

        if monitor != nil {
            NSLog("[HotkeyManager] 事件监听启动成功！语音输入: \(currentConfig.displayString), 系统音频: \(systemAudioConfig.displayString)")
        } else {
            NSLog("[HotkeyManager] 创建事件监听失败！请检查辅助功能权限。")
        }
    }

    private func handleFlagsChanged(event: NSEvent) {
        guard isEnabled else { return }

        // 先检测系统音频热键，如果匹配则跳过主热键处理
        let isSystemAudioTriggered = handleSystemAudioHotkey(event: event)
        guard !isSystemAudioTriggered else { return }

        switch currentConfig.triggerType {
        case .doubleTap:
            handleDoubleTapTrigger(event: event)
        case .longPress:
            handleLongPressTrigger(event: event)
        case .combination:
            handleCombinationTrigger(event: event)
        case .freeSpeak:
            handleFreeSpeakTrigger(event: event)
        }
    }

    // MARK: - System Audio Hotkey Detection (可配置)

    /// 检测系统音频热键（根据 systemAudioConfig 动态判断）
    /// 返回 true 表示检测到触发，主热键应跳过此事件
    private func handleSystemAudioHotkey(event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let targetKeyCode = systemAudioConfig.keyCode

        // 检查是否是目标键
        let isTargetKey = isMatchingModifierKey(keyCode: keyCode, targetKeyCode: targetKeyCode)
        guard isTargetKey else { return false }

        let isKeyPressed = isModifierKeyPressed(event: event, keyCode: targetKeyCode)

        switch systemAudioConfig.triggerType {
        case .doubleTap:
            return handleSystemAudioDoubleTap(isKeyPressed: isKeyPressed)
        case .longPress:
            return handleSystemAudioLongPress(isKeyPressed: isKeyPressed)
        default:
            return false
        }
    }

    private func handleSystemAudioDoubleTap(isKeyPressed: Bool) -> Bool {
        if isKeyPressed && !sysAudioKeyIsDown {
            sysAudioKeyIsDown = true
            let now = ProcessInfo.processInfo.systemUptime

            if now - sysAudioLastTapTime < systemAudioConfig.interval {
                sysAudioTapCount += 1
            } else {
                sysAudioTapCount = 1
            }
            sysAudioLastTapTime = now

            if sysAudioTapCount >= 2 {
                sysAudioTapCount = 0
                longPressTimer?.invalidate()
                longPressTimer = nil
                keyIsDown = false
                NSLog("[HotkeyManager] 系统音频热键触发: \(systemAudioConfig.displayString)")
                DispatchQueue.main.async { [weak self] in
                    self?.onSystemAudioDoubleTap?()
                }
                return true
            }
        } else if !isKeyPressed && sysAudioKeyIsDown {
            sysAudioKeyIsDown = false
        }
        return false
    }

    private func handleSystemAudioLongPress(isKeyPressed: Bool) -> Bool {
        if isKeyPressed && !sysAudioKeyIsDown {
            sysAudioKeyIsDown = true
            sysAudioKeyPressTime = ProcessInfo.processInfo.systemUptime

            sysAudioLongPressTimer = Timer.scheduledTimer(withTimeInterval: systemAudioConfig.interval, repeats: false) { [weak self] _ in
                guard let self = self, self.sysAudioKeyIsDown else { return }
                if self.isEnabled {
                    NSLog("[HotkeyManager] 系统音频长按触发: \(self.systemAudioConfig.displayString)")
                    // 重置主热键状态
                    self.longPressTimer?.invalidate()
                    self.longPressTimer = nil
                    self.keyIsDown = false
                    DispatchQueue.main.async {
                        self.onSystemAudioDoubleTap?()
                    }
                }
            }
            // 长按模式不立即返回 true，要等计时器触发
            // 但需要标记此键正在被系统音频监控
        } else if !isKeyPressed && sysAudioKeyIsDown {
            sysAudioKeyIsDown = false
            let pressDuration = ProcessInfo.processInfo.systemUptime - sysAudioKeyPressTime
            sysAudioLongPressTimer?.invalidate()
            sysAudioLongPressTimer = nil

            // 如果长按时间已超过阈值，说明已经触发过，返回 true 阻止主热键
            if pressDuration >= systemAudioConfig.interval {
                return true
            }
        }
        return false
    }

    private func handleKeyDown(event: NSEvent) {
        guard isEnabled else { return }
        guard currentConfig.triggerType == .combination else { return }

        // Check if this is a combination with a non-modifier key (like Space)
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check if the key matches and modifiers are held
        if keyCode == currentConfig.keyCode && modifiers.contains(currentConfig.modifiers) {
            // Trigger long press immediately for combination keys
            if !keyIsDown {
                keyIsDown = true
                keyPressTime = ProcessInfo.processInfo.systemUptime
                NSLog("[HotkeyManager] 组合键触发: \(currentConfig.displayString)")
                DispatchQueue.main.async { [weak self] in
                    self?.onLongPress?()
                }
            }
        }
    }

    private func handleLongPressTrigger(event: NSEvent) {
        let keyCode = event.keyCode
        let targetKeyCode = currentConfig.keyCode

        // Check for the specific modifier key
        let isTargetKey = isMatchingModifierKey(keyCode: keyCode, targetKeyCode: targetKeyCode)
        guard isTargetKey else { return }

        let isKeyPressed = isModifierKeyPressed(event: event, keyCode: targetKeyCode)

        if isKeyPressed && !keyIsDown {
            // Key pressed - start long press timer
            keyIsDown = true
            keyPressTime = ProcessInfo.processInfo.systemUptime

            longPressTimer = Timer.scheduledTimer(withTimeInterval: currentConfig.interval, repeats: false) { [weak self] _ in
                guard let self = self, self.keyIsDown else { return }
                if self.isEnabled {
                    NSLog("[HotkeyManager] 长按触发: \(self.currentConfig.displayString)")
                    DispatchQueue.main.async {
                        self.onLongPress?()
                    }
                }
            }
        } else if !isKeyPressed && keyIsDown {
            // Key released
            keyIsDown = false
            let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime

            longPressTimer?.invalidate()
            longPressTimer = nil

            if pressDuration >= currentConfig.interval && isEnabled {
                NSLog("[HotkeyManager] 长按结束 (持续 \(String(format: "%.2f", pressDuration))s)")
                DispatchQueue.main.async { [weak self] in
                    self?.onLongPressEnd?()
                }
            }
        }
    }

    private func handleDoubleTapTrigger(event: NSEvent) {
        let keyCode = event.keyCode
        let targetKeyCode = currentConfig.keyCode

        // Check for the specific modifier key
        // Left/Right variants: Ctrl (59/62), Option (58/61), Shift (56/60), Cmd (55/54)
        let isTargetKey = isMatchingModifierKey(keyCode: keyCode, targetKeyCode: targetKeyCode)
        guard isTargetKey else { return }

        let isKeyPressed = isModifierKeyPressed(event: event, keyCode: targetKeyCode)

        if isKeyPressed && !keyIsDown {
            // Key pressed
            keyIsDown = true
            let now = ProcessInfo.processInfo.systemUptime

            // Check for double tap
            if now - lastTapTime < currentConfig.interval {
                tapCount += 1
            } else {
                tapCount = 1
            }
            lastTapTime = now
            keyPressTime = now

            if tapCount >= 2 {
                // Double tap detected - start long press timer
                NSLog("[HotkeyManager] 双击检测到: \(currentConfig.displayString)")
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                    guard let self = self, self.keyIsDown else { return }
                    if self.isEnabled {
                        NSLog("[HotkeyManager] 双击长按触发")
                        DispatchQueue.main.async {
                            self.onLongPress?()
                        }
                    }
                }
            }
        } else if !isKeyPressed && keyIsDown {
            // Key released
            keyIsDown = false
            longPressTimer?.invalidate()
            longPressTimer = nil

            if tapCount >= 2 {
                let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime
                if pressDuration >= 0.1 && isEnabled {
                    NSLog("[HotkeyManager] 双击长按结束 (持续 \(String(format: "%.2f", pressDuration))s)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onLongPressEnd?()
                    }
                }
                tapCount = 0
            }
        }
    }

    private func handleFreeSpeakTrigger(event: NSEvent) {
        let keyCode = event.keyCode
        let targetKeyCode = currentConfig.keyCode

        let isTargetKey = isMatchingModifierKey(keyCode: keyCode, targetKeyCode: targetKeyCode)
        guard isTargetKey else { return }

        let isKeyPressed = isModifierKeyPressed(event: event, keyCode: targetKeyCode)

        // 自由说话模式：单击切换录音状态
        if isKeyPressed && !keyIsDown {
            keyIsDown = true
            keyPressTime = ProcessInfo.processInfo.systemUptime
        } else if !isKeyPressed && keyIsDown {
            keyIsDown = false
            let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime

            // 短按（<0.3s）触发切换
            if pressDuration < 0.3 && isEnabled {
                NSLog("[HotkeyManager] 自由说话模式：切换录音状态")
                DispatchQueue.main.async { [weak self] in
                    self?.onToggleRecording?()
                }
            }
        }
    }

    private func handleCombinationTrigger(event: NSEvent) {
        // For combination triggers, check if all required modifiers are pressed
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredModifiers = currentConfig.modifiers

        // Check if it's a modifier-only combination (no regular key)
        let isModifierOnlyCombo = currentConfig.keyCode == 0 || isModifierKeyCode(currentConfig.keyCode)

        if isModifierOnlyCombo {
            // Modifier-only combination (e.g., just hold Cmd+Option)
            if modifiers.contains(requiredModifiers) && !keyIsDown {
                keyIsDown = true
                keyPressTime = ProcessInfo.processInfo.systemUptime

                longPressTimer = Timer.scheduledTimer(withTimeInterval: currentConfig.interval, repeats: false) { [weak self] _ in
                    guard let self = self, self.keyIsDown else { return }
                    if self.isEnabled {
                        NSLog("[HotkeyManager] 组合键长按触发: \(self.currentConfig.displayString)")
                        DispatchQueue.main.async {
                            self.onLongPress?()
                        }
                    }
                }
            } else if !modifiers.contains(requiredModifiers) && keyIsDown {
                keyIsDown = false
                longPressTimer?.invalidate()
                longPressTimer = nil

                let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime
                if pressDuration >= currentConfig.interval && isEnabled {
                    NSLog("[HotkeyManager] 组合键长按结束")
                    DispatchQueue.main.async { [weak self] in
                        self?.onLongPressEnd?()
                    }
                }
            }
        } else {
            // Combination with regular key - release detection
            if keyIsDown && !modifiers.contains(requiredModifiers) {
                keyIsDown = false
                let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime
                NSLog("[HotkeyManager] 组合键释放 (持续 \(String(format: "%.2f", pressDuration))s)")
                DispatchQueue.main.async { [weak self] in
                    self?.onLongPressEnd?()
                }
            }
        }
    }

    private func isMatchingModifierKey(keyCode: UInt16, targetKeyCode: UInt16) -> Bool {
        // Map target key code to both left and right variants
        switch targetKeyCode {
        case 59, 62: // Control
            return keyCode == 59 || keyCode == 62
        case 58, 61: // Option
            return keyCode == 58 || keyCode == 61
        case 56, 60: // Shift
            return keyCode == 56 || keyCode == 60
        case 55, 54: // Command
            return keyCode == 55 || keyCode == 54
        case 63: // Fn
            return keyCode == 63
        default:
            return keyCode == targetKeyCode
        }
    }

    private func isModifierKeyPressed(event: NSEvent, keyCode: UInt16) -> Bool {
        let flags = event.modifierFlags
        switch keyCode {
        case 59, 62: // Control
            return flags.contains(.control)
        case 58, 61: // Option
            return flags.contains(.option)
        case 56, 60: // Shift
            return flags.contains(.shift)
        case 55, 54: // Command
            return flags.contains(.command)
        case 63: // Fn
            return flags.contains(.function)
        default:
            return false
        }
    }

    private func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        // Check if keyCode is a modifier key
        return [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(keyCode)
    }

    deinit {
        longPressTimer?.invalidate()
        sysAudioLongPressTimer?.invalidate()
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        if let keyDownMonitor = keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Configuration Persistence

    private static func loadConfig() -> HotkeyConfig {
        guard let savedData = UserDefaults.standard.data(forKey: "voiceflow.hotkeyConfig"),
              let config = try? JSONDecoder().decode(HotkeyConfig.self, from: savedData) else {
            return HotkeyConfig.default
        }
        return config
    }

    private static func loadSystemAudioConfig() -> HotkeyConfig {
        guard let savedData = UserDefaults.standard.data(forKey: "voiceflow.systemAudioHotkeyConfig"),
              let config = try? JSONDecoder().decode(HotkeyConfig.self, from: savedData) else {
            return HotkeyConfig.systemAudioDefault
        }
        return config
    }

    func saveConfig(_ config: HotkeyConfig) {
        guard let encoded = try? JSONEncoder().encode(config) else {
            NSLog("[HotkeyManager] Failed to encode config")
            return
        }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        currentConfig = config
        NSLog("[HotkeyManager] Config saved: \(config.displayString)")
    }

    func saveSystemAudioConfig(_ config: HotkeyConfig) {
        guard let encoded = try? JSONEncoder().encode(config) else {
            NSLog("[HotkeyManager] Failed to encode system audio config")
            return
        }
        UserDefaults.standard.set(encoded, forKey: systemAudioUserDefaultsKey)
        systemAudioConfig = config
        NSLog("[HotkeyManager] System audio config saved: \(config.displayString)")
    }

    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentConfig = HotkeyConfig.default
        NSLog("[HotkeyManager] Config reset to default: \(currentConfig.displayString)")
    }

    func resetSystemAudioToDefault() {
        UserDefaults.standard.removeObject(forKey: systemAudioUserDefaultsKey)
        systemAudioConfig = HotkeyConfig.systemAudioDefault
        NSLog("[HotkeyManager] System audio config reset to default: \(systemAudioConfig.displayString)")
    }

    func getCurrentConfig() -> HotkeyConfig {
        return currentConfig
    }

    func getSystemAudioConfig() -> HotkeyConfig {
        return systemAudioConfig
    }

    // MARK: - Hotkey Conflict Detection

    /// 检测快捷键冲突
    struct HotkeyConflict {
        let description: String
        let conflictingApp: String?
        let severity: ConflictSeverity

        enum ConflictSeverity {
            case warning   // 可能冲突
            case critical  // 确定冲突
        }
    }

    /// 检查当前配置是否与系统快捷键冲突
    func checkForConflicts() -> [HotkeyConflict] {
        var conflicts: [HotkeyConflict] = []

        let config = currentConfig

        // 检查常见系统快捷键冲突
        switch config.triggerType {
        case .longPress, .doubleTap, .freeSpeak:
            // 单独修饰键通常不会冲突
            break

        case .combination:
            // 检查组合键冲突
            if config.modifiers.contains(.command) {
                if config.keyCode == 49 { // Cmd + Space
                    conflicts.append(HotkeyConflict(
                        description: "⌘Space 与 Spotlight 搜索冲突",
                        conflictingApp: "Spotlight",
                        severity: .critical
                    ))
                }
                if config.keyCode == 12 { // Cmd + Q
                    conflicts.append(HotkeyConflict(
                        description: "⌘Q 与退出应用冲突",
                        conflictingApp: "系统",
                        severity: .critical
                    ))
                }
            }

            if config.modifiers.contains(.control) && config.modifiers.contains(.command) {
                if config.keyCode == 49 { // Ctrl + Cmd + Space
                    conflicts.append(HotkeyConflict(
                        description: "⌃⌘Space 与表情符号选择器冲突",
                        conflictingApp: "系统",
                        severity: .critical
                    ))
                }
            }

            if config.modifiers.contains(.option) && config.modifiers.contains(.command) {
                if config.keyCode == 53 { // Opt + Cmd + Esc
                    conflicts.append(HotkeyConflict(
                        description: "⌥⌘Esc 与强制退出冲突",
                        conflictingApp: "系统",
                        severity: .critical
                    ))
                }
            }
        }

        // 检查与其他语音输入工具的潜在冲突
        if config.triggerType == .doubleTap && config.keyCode == 59 { // Control 双击
            conflicts.append(HotkeyConflict(
                description: "Control 双击可能与 macOS 听写功能冲突",
                conflictingApp: "macOS 听写",
                severity: .warning
            ))
        }

        if !conflicts.isEmpty {
            NSLog("[HotkeyManager] Detected \(conflicts.count) potential conflicts")
        }

        return conflicts
    }

    /// 检查并显示冲突警告
    func checkAndWarnConflicts() {
        let conflicts = checkForConflicts()

        guard !conflicts.isEmpty else { return }

        let criticalConflicts = conflicts.filter { $0.severity == .critical }

        if !criticalConflicts.isEmpty {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "快捷键冲突警告"
                alert.informativeText = criticalConflicts.map { $0.description }.joined(separator: "\n")
                alert.alertStyle = .warning
                alert.addButton(withTitle: "知道了")
                alert.runModal()
            }
        }
    }
}
