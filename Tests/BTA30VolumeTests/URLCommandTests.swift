import XCTest
@testable import BTA30Volume

final class URLCommandTests: XCTestCase {
    private func parse(_ string: String) -> URLCommand? {
        guard let url = URL(string: string) else { return nil }
        return URLCommand.parse(url)
    }

    func testVolumeCommands() {
        XCTAssertEqual(parse("bta30://volume/25"), .setVolume(25))
        XCTAssertEqual(parse("bta30://volume/up"), .volumeUp)
        XCTAssertEqual(parse("bta30://volume/down"), .volumeDown)
        XCTAssertNil(parse("bta30://volume/loud"))
    }

    func testMute() {
        XCTAssertEqual(parse("bta30://mute"), .mute)
    }

    func testBalanceAcceptsNegativeValues() {
        XCTAssertEqual(parse("bta30://balance/-3"), .balance(-3))
        XCTAssertEqual(parse("bta30://balance/12"), .balance(12))
    }

    func testFilter() {
        XCTAssertEqual(parse("bta30://filter/2"), .filter(2))
    }

    func testLed() {
        XCTAssertEqual(parse("bta30://led/on"), .led(off: false))
        XCTAssertEqual(parse("bta30://led/off"), .led(off: true))
        XCTAssertNil(parse("bta30://led/maybe"))
    }

    func testUpsampling() {
        XCTAssertEqual(parse("bta30://upsampling/on"), .upsampling(true))
        XCTAssertEqual(parse("bta30://upsampling/off"), .upsampling(false))
    }

    func testPowerOff() {
        XCTAssertEqual(parse("bta30://power/off"), .powerOff)
        XCTAssertNil(parse("bta30://power/on"))
    }

    func testPresetPreservesRawName() {
        // Percent encoding must be decoded, letter case preserved
        XCTAssertEqual(parse("bta30://preset/Night%20Mode"), .preset(name: "Night Mode"))
        XCTAssertNil(parse("bta30://preset"))
    }

    func testRejectsOtherSchemesAndUnknownCommands() {
        XCTAssertNil(parse("https://volume/25"))
        XCTAssertNil(parse("bta30://dance/1"))
    }
}
