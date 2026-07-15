import AppKit
import Carbon
import XCTest
@testable import BTA30Volume

final class HotKeySpecTests: XCTestCase {
    func testDefaultBindings() {
        let bindings = HotKeyAction.defaultBindings
        XCTAssertEqual(bindings[.volumeUp]?.keyCode, UInt32(kVK_UpArrow))
        XCTAssertEqual(bindings[.volumeDown]?.keyCode, UInt32(kVK_DownArrow))
        XCTAssertEqual(bindings[.mute]?.keyCode, UInt32(kVK_ANSI_0))
        for spec in bindings.values {
            XCTAssertEqual(
                NSEvent.ModifierFlags(rawValue: spec.modifierFlags),
                [.option, .command]
            )
        }
    }

    func testDisplayStringForDefaultVolumeUp() {
        XCTAssertEqual(HotKeyAction.volumeUp.defaultSpec.displayString, "⌥⌘↑")
    }

    func testDisplayStringModifierOrderIsControlOptionShiftCommand() {
        let spec = HotKeySpec(
            keyCode: UInt32(kVK_DownArrow),
            modifierFlags: NSEvent.ModifierFlags([.command, .shift, .option, .control]).rawValue
        )
        XCTAssertEqual(spec.displayString, "⌃⌥⇧⌘↓")
    }

    func testCodableRoundTrip() throws {
        let bindings: [HotKeyAction: HotKeySpec] = [
            .mute: HotKeySpec(keyCode: 49, modifierFlags: NSEvent.ModifierFlags([.control, .command]).rawValue)
        ]
        let data = try JSONEncoder().encode(bindings)
        let decoded = try JSONDecoder().decode([HotKeyAction: HotKeySpec].self, from: data)
        XCTAssertEqual(decoded, bindings)
    }

    func testCarbonIDMappingIsBijective() {
        for action in HotKeyAction.allCases {
            XCTAssertEqual(HotKeyAction.from(carbonID: action.carbonID), action)
        }
        XCTAssertNil(HotKeyAction.from(carbonID: 99))
    }
}
