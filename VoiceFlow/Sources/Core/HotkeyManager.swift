import AppKit
import Carbon
import os

private let logger = Logger(subsystem: "com.voiceflow.app", category: "HotkeyManager")

final class HotkeyManager {
    var onDoubleTap: (() -> Void)?

    private var lastControlTapTime: TimeInterval = 0
    private var controlIsDown = false
    private var otherKeyWhileControl = false
    private var eventTap: CFMachPort?
    private let doubleTapInterval: TimeInterval = 0.3
    private var isEnabled = true

    func enable() {
        isEnabled = true
        NSLog("[HotkeyManager] Hotkey enabled")
    }

    func disable() {
        isEnabled = false
        NSLog("[HotkeyManager] Hotkey disabled")
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
        if type == .keyDown {
            if controlIsDown {
                otherKeyWhileControl = true
            }
            return
        }

        guard type == .flagsChanged else { return }

        let flags = event.flags
        let controlPressed = flags.contains(.maskControl)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        NSLog("[HotkeyManager] flagsChanged: keyCode=\(keyCode), control=\(controlPressed)")

        // Accept both Left Control (59) and Right Control (62)
        guard keyCode == 59 || keyCode == 62 else { return }

        if controlPressed && !controlIsDown {
            // Control key pressed down
            controlIsDown = true
            otherKeyWhileControl = false
        } else if !controlPressed && controlIsDown {
            // Control key released
            controlIsDown = false

            if otherKeyWhileControl {
                // Was used as modifier, ignore
                otherKeyWhileControl = false
                return
            }

            // Solo control tap
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - lastControlTapTime

            if elapsed <= doubleTapInterval {
                lastControlTapTime = 0
                if isEnabled {
                    DispatchQueue.main.async { [weak self] in
                        self?.onDoubleTap?()
                    }
                }
            } else {
                lastControlTapTime = now
            }
        }
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
