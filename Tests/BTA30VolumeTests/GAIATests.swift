import XCTest
@testable import BTA30Volume

/// GAIA frame encoding/decoding tests.
///
/// Reference bytes come from traffic verified against a real BTA30 Pro.
final class GAIATests: XCTestCase {
    // MARK: - Request frames

    func testSetVolumeRequestFrame() {
        XCTAssertEqual(
            GAIA.request(.setVolume, payload: [42]),
            Data([0x00, 0x0A, 0x04, 0x02, 0x2A])
        )
    }

    func testGetVolumeRequestFrameHasNoPayload() {
        XCTAssertEqual(
            GAIA.request(.getVolume),
            Data([0x00, 0x0A, 0x04, 0x12])
        )
    }

    func testBalanceRequestEncodesSideAndAmount() {
        XCTAssertEqual(
            GAIA.request(.setBalance, payload: [0x01, 0x03]),
            Data([0x00, 0x0A, 0x04, 0x03, 0x01, 0x03])
        )
    }

    // MARK: - Response parsing

    func testParseVolumeResponse() {
        // Real capture from the device: volume 42 notification
        let response = GAIA.parseResponse(Data([0x00, 0x0A, 0x84, 0x12, 0x00, 0x2A]))
        XCTAssertEqual(response, GAIA.Response(commandID: 0x412, payload: [0x2A]))
    }

    func testParseAckWithoutPayload() {
        // SET_VOLUME acknowledgement: empty payload
        let response = GAIA.parseResponse(Data([0x00, 0x0A, 0x84, 0x02, 0x00]))
        XCTAssertEqual(response, GAIA.Response(commandID: 0x402, payload: []))
    }

    func testParseMultiBytePayload() {
        let response = GAIA.parseResponse(Data([0x00, 0x0A, 0x84, 0x18, 0x00, 0x01, 0x02, 0xD4]))
        XCTAssertEqual(response, GAIA.Response(commandID: 0x418, payload: [0x01, 0x02, 0xD4]))
    }

    func testParseRejectsWrongMagic() {
        XCTAssertNil(GAIA.parseResponse(Data([0x01, 0x0A, 0x84, 0x12, 0x00, 0x2A])))
        XCTAssertNil(GAIA.parseResponse(Data([0x00, 0x0B, 0x84, 0x12, 0x00, 0x2A])))
    }

    func testParseRejectsRequestDirectionFrame() {
        // A request frame (0x0X) must not be accepted as a response
        XCTAssertNil(GAIA.parseResponse(Data([0x00, 0x0A, 0x04, 0x12, 0x00])))
    }

    func testParseRejectsTooShortData() {
        XCTAssertNil(GAIA.parseResponse(Data([0x00, 0x0A, 0x84, 0x12])))
        XCTAssertNil(GAIA.parseResponse(Data()))
    }
}
