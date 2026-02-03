import AppKit
import Carbon
import os

private let logger = Logger(subsystem: "com.voiceflow.app", category: "HotkeyManager")

final class HotkeyManager {
    var onDoubleTap: (() -> Void)?

    private var currentConfig: HotkeyConfig
    private var lastControlTapTime: TimeInterval = 0
    private var controlIsDown = false
    private var otherKeyWhileControl = false
    private var eventTap: CFMachPort?
    private let userDefaultsKey = "voiceflow.hotkeyConfig"

    init() {
        // Load config from UserDefaults or use default
        currentConfig = HotkeyManager.loadConfig()
    }

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                      (1 << CGEventType.keyDown.rawValue)

        NSLog("[HotkeyManager] Attempting to create event tap...")

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handleEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("[HotkeyManager] FAILED to create event tap! Check permissions.")
            return
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[HotkeyManager] Event tap started successfully!")
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Handle combination trigger type
        if currentConfig.triggerType == .combination {
            guard type == .keyDown else { return }

            // Check if this is our configured key
            guard keyCode == currentConfig.keyCode else { return }

            // Check if modifiers match
            let flags = event.flags
            let hasCommand = flags.contains(.maskCommand)
            let hasOption = flags.contains(.maskAlternate)
            let hasControl = flags.contains(.maskControl)
            let hasShift = flags.contains(.maskShift)

            let wantCommand = currentConfig.modifiers.contains(.command)
            let wantOption = currentConfig.modifiers.contains(.option)
            let wantControl = currentConfig.modifiers.contains(.control)
            let wantShift = currentConfig.modifiers.contains(.shift)

            if hasCommand == wantCommand && hasOption == wantOption &&
               hasControl == wantControl && hasShift == wantShift {
                NSLog("[HotkeyManager] Combination hotkey triggered!")
                DispatchQueue.main.async { [weak self] in
                    self?.onDoubleTap?()
                }
            }
            return
        }

        // Handle double-tap trigger type
        if type == .keyDown {
            if controlIsDown {
                otherKeyWhileControl = true
            }
            return
        }

        guard type == .flagsChanged else { return }

        let flags = event.flags
        let keyPressed = isKeyPressed(keyCode: keyCode, flags: flags)

        NSLog("[HotkeyManager] flagsChanged: keyCode=\(keyCode), pressed=\(keyPressed)")

        // Check if this is our configured key
        guard keyCode == currentConfig.keyCode else { return }

        if keyPressed && !controlIsDown {
            // Key pressed down
            controlIsDown = true
            otherKeyWhileControl = false
        } else if !keyPressed && controlIsDown {
            // Key released
            controlIsDown = false

            if otherKeyWhileControl {
                // Was used as modifier, ignore
                otherKeyWhileControl = false
                return
            }

            // Solo key tap
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - lastControlTapTime

            if elapsed <= currentConfig.interval {
                lastControlTapTime = 0
                NSLog("[HotkeyManager] Double-tap hotkey triggered!")
                DispatchQueue.main.async { [weak self] in
                    self?.onDoubleTap?()
                }
            } else {
                lastControlTapTime = now
            }
        }
    }

    private func isKeyPressed(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        // Map common modifier keys to their flag masks
        switch keyCode {
        case 59, 62: // Left/Right Control
            return flags.contains(.maskControl)
        case 55, 54: // Left/Right Command
            return flags.contains(.maskCommand)
        case 58, 61: // Left/Right Option
            return flags.contains(.maskAlternate)
        case 56, 60: // Left/Right Shift
            return flags.contains(.maskShift)
        default:
            // For non-modifier keys, check if any modifier is active
            return flags.contains(.maskControl) || flags.contains(.maskCommand) ||
                   flags.contains(.maskAlternate) || flags.contains(.maskShift)
        }
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    // MARK: - Configuration Persistence

    private static func loadConfig() -> HotkeyConfig {
        guard let savedData = UserDefaults.standard.data(forKey: "voiceflow.hotkeyConfig"),
              let config = try? JSONDecoder().decode(HotkeyConfig.self, from: savedData) else {
            return HotkeyConfig.default
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

    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentConfig = HotkeyConfig.default
        NSLog("[HotkeyManager] Config reset to default: \(currentConfig.displayString)")
    }
}

