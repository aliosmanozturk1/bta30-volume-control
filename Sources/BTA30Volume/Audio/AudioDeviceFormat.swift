import CoreAudio
import Foundation

/// CoreAudio helpers: locating the FiiO device and reading its audio format.
enum AudioDeviceFormat {
    static func deviceName(_ id: AudioObjectID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let cf = name?.takeRetainedValue() else { return "" }
        return cf as String
    }

    static func findFiiODevice() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else { return 0 }
        var deviceIDs = [AudioObjectID](
            repeating: 0, count: Int(dataSize) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs) == noErr else { return 0 }
        return deviceIDs.first { deviceName($0).uppercased().contains("BTA30") } ?? 0
    }

    /// Returns the device's current format as "44.1 kHz / 24-bit".
    static func readFormat(_ deviceID: AudioObjectID) -> String {
        var rateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var rate: Float64 = 0
        var rateSize = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(deviceID, &rateAddress, 0, nil, &rateSize, &rate) == noErr,
              rate > 0 else { return "" }

        // Bit depth: from the physical format of the first output stream
        var bits = 0
        var streamsAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var streamsSize: UInt32 = 0
        if AudioObjectGetPropertyDataSize(deviceID, &streamsAddress, 0, nil, &streamsSize) == noErr,
           streamsSize > 0 {
            var streams = [AudioStreamID](
                repeating: 0, count: Int(streamsSize) / MemoryLayout<AudioStreamID>.size)
            if AudioObjectGetPropertyData(deviceID, &streamsAddress, 0, nil, &streamsSize, &streams) == noErr,
               let stream = streams.first {
                var formatAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioStreamPropertyPhysicalFormat,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain)
                var format = AudioStreamBasicDescription()
                var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                if AudioObjectGetPropertyData(stream, &formatAddress, 0, nil, &formatSize, &format) == noErr {
                    bits = Int(format.mBitsPerChannel)
                }
            }
        }

        let kHz = rate / 1000
        let rateText = kHz == kHz.rounded() ? String(format: "%.0f", kHz) : String(format: "%.1f", kHz)
        return bits > 0 ? "\(rateText) kHz / \(bits)-bit" : "\(rateText) kHz"
    }
}
