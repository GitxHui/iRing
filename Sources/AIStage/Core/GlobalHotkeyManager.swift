import Carbon
import Foundation

/// Carbon global hotkey registration (reliable, zero Input Monitoring permission needed).
public final class GlobalHotkeyManager {

    public enum Action: Equatable {
        case toggleStage
        case moveToNextScreen
        case radialTriggerPressed
        case radialTriggerReleased
        case splitRingPressed
        case splitRingReleased
        case switchToSlot(Int) // 0-based index 0..8
    }

    private static let signature: OSType = 0x41495354 // "AIST"

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var idToAction: [UInt32: Action] = [:]
    private var onAction: ((Action) -> Void)?

    public init() {}

    deinit {
        unregisterAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    public func configure(
        toggleShortcut: CustomKeyCombo,
        moveScreenShortcut: CustomKeyCombo,
        radialShortcut: CustomKeyCombo?,
        splitRingShortcut: CustomKeyCombo? = nil,
        numberModifier: NumberSwitchModifier,
        handler: @escaping (Action) -> Void
    ) {
        self.onAction = handler
        installHandlerIfNeeded()
        unregisterAll()

        // 1. Toggle Stage Show / Hide
        if toggleShortcut.isValidShortcut {
            register(
                id: 100,
                keyCode: toggleShortcut.keyCode,
                modifiers: carbonModifiers(from: toggleShortcut.modifiers),
                action: .toggleStage
            )
        }

        // 2. Move Stage to Next Screen
        if moveScreenShortcut.isValidShortcut && moveScreenShortcut != toggleShortcut {
            register(
                id: 101,
                keyCode: moveScreenShortcut.keyCode,
                modifiers: carbonModifiers(from: moveScreenShortcut.modifiers),
                action: .moveToNextScreen
            )
        }

        // 3. Optional Keyboard Shortcut for Loop Radial Switcher
        if let radial = radialShortcut,
           radial.isValidShortcut,
           radial != toggleShortcut,
           radial != moveScreenShortcut {
            register(
                id: 102,
                keyCode: radial.keyCode,
                modifiers: carbonModifiers(from: radial.modifiers),
                action: .radialTriggerPressed
            )
        }

        // 3b. Dedicated Loop Split Ring Hotkey
        if let split = splitRingShortcut,
           split.isValidShortcut,
           split != toggleShortcut,
           split != moveScreenShortcut,
           split != radialShortcut {
            register(
                id: 103,
                keyCode: split.keyCode,
                modifiers: carbonModifiers(from: split.modifiers),
                action: .splitRingPressed
            )
        }

        // 4. Number-key Quick Switch (1..9)
        let numKeyCodes: [Int] = [
            kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3,
            kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6,
            kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
        ]

        let modMask: UInt32?
        switch numberModifier {
        case .option:
            modMask = UInt32(optionKey)
        case .command:
            modMask = UInt32(cmdKey)
        case .disabled:
            modMask = nil
        }

        if let mask = modMask {
            for (index, keyCode) in numKeyCodes.enumerated() {
                register(
                    id: UInt32(200 + index),
                    keyCode: UInt32(keyCode),
                    modifiers: mask,
                    action: .switchToSlot(index)
                )
            }
        }
    }

    public func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        idToAction.removeAll()
    }

    private func carbonModifiers(from portable: UInt32) -> UInt32 {
        var result: UInt32 = 0
        if (portable & CustomKeyCombo.modControl) != 0 { result |= UInt32(controlKey) }
        if (portable & CustomKeyCombo.modOption) != 0 { result |= UInt32(optionKey) }
        if (portable & CustomKeyCombo.modShift) != 0 { result |= UInt32(shiftKey) }
        if (portable & CustomKeyCombo.modCommand) != 0 { result |= UInt32(cmdKey) }
        return result
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        let eventSpecs = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]

        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event = event, let userData = userData else {
                return OSStatus(eventNotHandledErr)
            }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr,
                  hotKeyID.signature == GlobalHotkeyManager.signature,
                  let registeredAction = manager.idToAction[hotKeyID.id]
            else {
                return OSStatus(eventNotHandledErr)
            }

            let kind = GetEventKind(event)
            if kind == UInt32(kEventHotKeyPressed) {
                DispatchQueue.main.async {
                    manager.onAction?(registeredAction)
                }
                return noErr
            } else if kind == UInt32(kEventHotKeyReleased) {
                if registeredAction == .radialTriggerPressed {
                    DispatchQueue.main.async {
                        manager.onAction?(.radialTriggerReleased)
                    }
                    return noErr
                } else if registeredAction == .splitRingPressed {
                    DispatchQueue.main.async {
                        manager.onAction?(.splitRingReleased)
                    }
                    return noErr
                }
            }
            return OSStatus(eventNotHandledErr)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = eventSpecs.withUnsafeBufferPointer { ptr in
            InstallEventHandler(
                GetApplicationEventTarget(),
                callback,
                ptr.count,
                ptr.baseAddress,
                selfPtr,
                &eventHandlerRef
            )
        }
        if installStatus != noErr {
            NSLog("[AIStage] InstallEventHandler failed status=\(installStatus)")
        }
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: Action) {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref = ref {
            hotKeyRefs[id] = ref
            idToAction[id] = action
        } else {
            NSLog("[AIStage] Hotkey registration failed for id=\(id) status=\(status)")
        }
    }
}
