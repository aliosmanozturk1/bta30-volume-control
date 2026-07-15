import Foundation

/// GAIA command IDs understood by the FiiO BTA30.
///
/// Protocol documentation: https://github.com/Hypfer/fiio-bta30-protocol
enum GAIACommand: UInt16 {
    case setVolume = 0x402
    case getVolume = 0x412
    case setFilter = 0x401
    case getFilter = 0x411
    /// LED mode: 0x01 = LEDs on (verified on the BTA30 Pro; the Hypfer docs
    /// state the opposite for the non-Pro model)
    case setLedMode = 0x43E
    case getLedMode = 0x43D
    case setBalance = 0x403
    case getBalance = 0x413
    case setUpsampling = 0x451
    case getUpsampling = 0x450
    case setBootMode = 0x40B
    case getBootMode = 0x41C
    case getVersion = 0x418
    case powerOff = 0x425
}

/// Qualcomm GAIA BLE frames (CSR8675).
///
/// Request : `00 0a 0X XX [payload]`  (20-bit magic 0x000a0 + 12-bit command ID)
/// Response: `00 0a 8X XX 00 [payload]`
enum GAIA {
    struct Response: Equatable {
        let commandID: UInt16
        let payload: [UInt8]
    }

    static func request(_ command: GAIACommand, payload: [UInt8] = []) -> Data {
        let raw = command.rawValue
        return Data([0x00, 0x0A, UInt8((raw >> 8) & 0x0F), UInt8(raw & 0xFF)] + payload)
    }

    static func parseResponse(_ data: Data) -> Response? {
        let bytes = [UInt8](data)
        guard bytes.count >= 5, bytes[0] == 0x00, bytes[1] == 0x0A, (bytes[2] & 0xF0) == 0x80 else {
            return nil
        }
        let commandID = (UInt16(bytes[2] & 0x0F) << 8) | UInt16(bytes[3])
        return Response(commandID: commandID, payload: [UInt8](bytes.dropFirst(5)))
    }
}
