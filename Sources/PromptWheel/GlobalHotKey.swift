import Carbon

@MainActor
final class GlobalHotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var isDown = false
    var onPress: (() -> Void)?

    func register() -> OSStatus {
        stop()
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let hotkey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    hotkey.isDown = false
                } else if !hotkey.isDown {
                    hotkey.isDown = true
                    hotkey.onPress?()
                }
                return noErr
            }
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return installed }
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey),
            EventHotKeyID(signature: 0x5057484C, id: 1), GetApplicationEventTarget(),
            UInt32(kEventHotKeyExclusive), &reference)
        if status != noErr { stop() }
        return status
    }

    func stop() {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
        reference = nil
        handler = nil
        isDown = false
    }
}
