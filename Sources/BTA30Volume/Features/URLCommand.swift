import Foundation

/// Pure parser for the `bta30://` URL scheme. Execution lives in AppModel.
///
/// Supported forms:
///   bta30://volume/35   bta30://volume/up   bta30://volume/down
///   bta30://mute        bta30://balance/-3  bta30://filter/2
///   bta30://led/on      bta30://led/off     bta30://upsampling/on
///   bta30://power/off   bta30://preset/night
enum URLCommand: Equatable {
    case setVolume(Int)
    case volumeUp
    case volumeDown
    case mute
    case balance(Int)
    case filter(Int)
    case led(off: Bool)
    case upsampling(Bool)
    case powerOff
    case preset(name: String)

    static func parse(_ url: URL) -> URLCommand? {
        guard url.scheme?.lowercased() == "bta30" else { return nil }
        let command = url.host?.lowercased() ?? ""
        // Preserve the raw argument for preset names (case, spaces, etc.)
        let rawArgument = url.pathComponents.count > 1 ? url.pathComponents[1] : ""
        let argument = rawArgument.lowercased()

        switch command {
        case "volume":
            if argument == "up" { return .volumeUp }
            if argument == "down" { return .volumeDown }
            if let value = Int(argument) { return .setVolume(value) }
            return nil
        case "mute":
            return .mute
        case "balance":
            return Int(argument).map { .balance($0) }
        case "filter":
            return Int(argument).map { .filter($0) }
        case "led":
            if argument == "on" { return .led(off: false) }
            if argument == "off" { return .led(off: true) }
            return nil
        case "upsampling":
            return .upsampling(argument == "on")
        case "power":
            return argument == "off" ? .powerOff : nil
        case "preset":
            return rawArgument.isEmpty ? nil : .preset(name: rawArgument)
        default:
            return nil
        }
    }
}
