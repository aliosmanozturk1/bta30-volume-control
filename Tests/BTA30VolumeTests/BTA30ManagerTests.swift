import XCTest
@testable import BTA30Volume

/// Captures every frame the manager tries to send.
private final class TestTransport: GAIATransport {
    var frames: [Data] = []
    func send(_ data: Data) { frames.append(data) }
}

/// Runs write actions synchronously so tests stay deterministic.
private final class ImmediateWriteScheduler: WriteScheduling {
    var hasPending = false
    func send(_ action: @escaping () -> Void) { action() }
}

/// Controllable clock for echo-window tests.
private final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class BTA30ManagerTests: XCTestCase {
    private var manager: BTA30Manager!
    private var transport: TestTransport!
    private var clock: TestClock!
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.bta30.manager.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        transport = TestTransport()
        clock = TestClock()
        let clock = self.clock!
        manager = BTA30Manager(
            central: nil,
            defaults: defaults,
            volumeWriter: ImmediateWriteScheduler(),
            balanceWriter: ImmediateWriteScheduler(),
            resyncWriter: ImmediateWriteScheduler(),
            now: { clock.now }
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    private static let stateRequestCount = 7

    /// Connects the fake transport and clears the initial state-request frames.
    private func connect() {
        manager.transportDidConnect(transport)
        transport.frames.removeAll()
    }

    /// Simulates an unsolicited notification from the device.
    private func push(_ command: GAIACommand, _ payload: [UInt8]) {
        let raw = command.rawValue
        manager.receive(Data([0x00, 0x0A, 0x80 | UInt8((raw >> 8) & 0x0F), UInt8(raw & 0xFF), 0x00] + payload))
    }

    // MARK: - Connection

    func testConnectRequestsFullDeviceState() {
        manager.transportDidConnect(transport)
        XCTAssertEqual(manager.state, .connected)
        XCTAssertEqual(transport.frames.count, Self.stateRequestCount)
        XCTAssertEqual(transport.frames.first, GAIA.request(.getVolume))
    }

    func testActionsProduceNoFramesAfterDisconnect() {
        connect()
        manager.transportDidDisconnect()
        XCTAssertEqual(manager.state, .connecting)
        manager.setVolume(30)
        manager.toggleMute()
        XCTAssertTrue(transport.frames.isEmpty)
        XCTAssertEqual(manager.volume, 0)
    }

    // MARK: - Volume writes and limit

    func testSetVolumeSendsFrameAndUpdatesState() {
        connect()
        manager.setVolume(42)
        XCTAssertEqual(manager.volume, 42)
        XCTAssertEqual(transport.frames, [GAIA.request(.setVolume, payload: [42])])
    }

    func testSetVolumeClampsToLimit() {
        connect()
        manager.volumeLimit = 40
        manager.setVolume(55)
        XCTAssertEqual(manager.volume, 40)
        XCTAssertEqual(transport.frames.last, GAIA.request(.setVolume, payload: [40]))
    }

    func testLoweringLimitPullsCurrentVolumeDown() {
        connect()
        manager.setVolume(50)
        transport.frames.removeAll()
        manager.volumeLimit = 30
        XCTAssertEqual(manager.volume, 30)
        XCTAssertEqual(transport.frames, [GAIA.request(.setVolume, payload: [30])])
    }

    // MARK: - Remote pushes

    func testVolumeEchoSuppressedWithinWindow() {
        connect()
        manager.setVolume(30)
        push(.getVolume, [29])
        XCTAssertEqual(manager.volume, 30, "echo within the window must be ignored")

        clock.advance(1)
        push(.getVolume, [29])
        XCTAssertEqual(manager.volume, 29, "a push after the window is real and must apply")
    }

    func testRemotePushAboveLimitIsClampedBack() {
        connect()
        manager.volumeLimit = 40
        clock.advance(1)
        transport.frames.removeAll()
        push(.getVolume, [55])
        XCTAssertEqual(manager.volume, 40)
        XCTAssertEqual(transport.frames.last, GAIA.request(.setVolume, payload: [40]))
    }

    func testLedModePushUsesInvertedSemantics() {
        connect()
        push(.getLedMode, [0x01])
        XCTAssertFalse(manager.ledOff, "0x01 means LEDs on (verified on the Pro)")
        push(.getLedMode, [0x00])
        XCTAssertTrue(manager.ledOff)
    }

    // MARK: - Mute

    func testToggleMuteRemembersAndRestoresVolume() {
        connect()
        manager.setVolume(30)
        manager.toggleMute()
        XCTAssertEqual(manager.volume, 0)
        manager.toggleMute()
        XCTAssertEqual(manager.volume, 30)
    }

    func testUnmuteWithoutRememberedVolumeUsesFallback() {
        connect()
        XCTAssertEqual(manager.volume, 0)
        manager.toggleMute()
        XCTAssertEqual(manager.volume, 20)
    }

    // MARK: - Other setters

    func testBalanceEncodesSideAndAmount() {
        connect()
        manager.setBalance(-3)
        XCTAssertEqual(transport.frames.last, GAIA.request(.setBalance, payload: [0x01, 0x03]))
        manager.setBalance(5)
        XCTAssertEqual(transport.frames.last, GAIA.request(.setBalance, payload: [0x02, 0x05]))
    }

    func testSetLedOffSendsInvertedFlag() {
        connect()
        manager.setLedOff(true)
        XCTAssertEqual(transport.frames.last, GAIA.request(.setLedMode, payload: [0x00]))
        manager.setLedOff(false)
        XCTAssertEqual(transport.frames.last, GAIA.request(.setLedMode, payload: [0x01]))
    }

    // MARK: - Write failure

    func testWriteFailureTriggersStateResync() {
        connect()
        manager.writeDidFail(NSError(domain: "test", code: 1))
        XCTAssertEqual(transport.frames.count, Self.stateRequestCount)
        XCTAssertEqual(transport.frames.first, GAIA.request(.getVolume))
    }

    // MARK: - User-visible issues

    func testWriteFailureSurfacesIssueAndInboundDataClearsIt() {
        connect()
        XCTAssertNil(manager.lastIssue)

        manager.writeDidFail(NSError(domain: "test", code: 1))
        XCTAssertEqual(manager.lastIssue, .writeFailed)

        // Any valid response from the device proves the link is healthy again
        push(.getVolume, [10])
        XCTAssertNil(manager.lastIssue)
    }

    func testReconnectClearsIssue() {
        connect()
        manager.writeDidFail(NSError(domain: "test", code: 1))
        manager.transportDidDisconnect()
        manager.transportDidConnect(transport)
        XCTAssertNil(manager.lastIssue)
    }
}
