import CoreAudio
import Foundation

/// Watches macOS's default audio output device and the FiiO's USB format.
///
/// Used so media keys are only captured while FiiO is the active output; with
/// any other device (e.g. built-in speakers) selected, keys pass through to
/// the system. CoreAudio read details live in `AudioDeviceFormat`.
final class AudioOutputWatcher: ObservableObject {
    @Published private(set) var isFiiODefaultOutput = false
    @Published private(set) var currentOutputName = ""
    /// The FiiO's current USB audio format, e.g. "44.1 kHz / 24-bit"
    @Published private(set) var fiioFormat = ""

    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var deviceListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var sampleRateAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyNominalSampleRate,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var fiioDeviceID: AudioObjectID = 0
    // Both listener blocks are stored so they can be removed again in deinit —
    // an inline closure passed to AudioObjectAddPropertyListenerBlock could
    // never be unregistered.
    private lazy var changeListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.refreshFormat()
    }
    private lazy var defaultOutputListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.updateDefaultOutput()
    }

    init() {
        updateDefaultOutput()
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            .main,
            defaultOutputListener
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceListAddress,
            .main,
            changeListener
        )
        refreshFormat()
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, .main, defaultOutputListener)
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &deviceListAddress, .main, changeListener)
        if fiioDeviceID != 0 {
            AudioObjectRemovePropertyListenerBlock(fiioDeviceID, &sampleRateAddress, .main, changeListener)
        }
    }

    private func updateDefaultOutput() {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = defaultOutputAddress
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        let name = (status == noErr && deviceID != 0) ? AudioDeviceFormat.deviceName(deviceID) : ""
        currentOutputName = name.trimmingCharacters(in: .whitespaces)
        isFiiODefaultOutput = name.uppercased().contains("BTA30")
    }

    func refreshFormat() {
        let located = AudioDeviceFormat.findFiiODevice()
        if located != fiioDeviceID {
            if fiioDeviceID != 0 {
                AudioObjectRemovePropertyListenerBlock(fiioDeviceID, &sampleRateAddress, .main, changeListener)
            }
            fiioDeviceID = located
            if fiioDeviceID != 0 {
                AudioObjectAddPropertyListenerBlock(fiioDeviceID, &sampleRateAddress, .main, changeListener)
            }
        }
        fiioFormat = fiioDeviceID != 0 ? AudioDeviceFormat.readFormat(fiioDeviceID) : ""
    }
}
