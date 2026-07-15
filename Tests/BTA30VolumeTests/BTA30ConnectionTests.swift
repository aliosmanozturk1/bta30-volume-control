import CoreBluetooth
import XCTest
@testable import BTA30Volume

private final class FakeHandle: BLEPeripheralHandle {
    let id: UUID
    let peripheralName: String?
    init(id: UUID = UUID(), name: String?) {
        self.id = id
        self.peripheralName = name
    }
}

private final class FakeCentral: BLECentralControlling {
    weak var events: BLECentralEvents?
    var isPoweredOn = true
    var scanCount = 0
    var stopScanCount = 0
    var connectRequests: [BLEPeripheralHandle] = []
    var knownPeripheral: BLEPeripheralHandle?

    func scanAll() { scanCount += 1 }
    func stopScan() { stopScanCount += 1 }
    func connect(_ peripheral: BLEPeripheralHandle) { connectRequests.append(peripheral) }
    func retrieveKnown(id: UUID) -> BLEPeripheralHandle? { knownPeripheral }
}

private final class FrameSink: GAIATransport {
    var frames: [Data] = []
    func send(_ data: Data) { frames.append(data) }
}

private final class ImmediateScheduler: WriteScheduling {
    var hasPending = false
    func send(_ action: @escaping () -> Void) { action() }
}

/// Collects retry closures so tests decide when the retry timer "fires".
private final class RetryBox {
    var pending: [() -> Void] = []
    func fireAll() {
        let works = pending
        pending = []
        works.forEach { $0() }
    }
}

/// Discovery / connect / reconnect decisions, driven through the
/// `BLECentralControlling` seam with a fake central.
final class BTA30ConnectionTests: XCTestCase {
    private var manager: BTA30Manager!
    private var central: FakeCentral!
    private var retries: RetryBox!
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.bta30.connection.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        central = FakeCentral()
        retries = RetryBox()
        let retries = self.retries!
        manager = BTA30Manager(
            central: central,
            defaults: defaults,
            volumeWriter: ImmediateScheduler(),
            balanceWriter: ImmediateScheduler(),
            resyncWriter: ImmediateScheduler(),
            retryScheduler: { _, work in retries.pending.append(work) }
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Search start

    func testInitWiresItselfAsCentralEvents() {
        XCTAssertTrue(central.events === manager)
    }

    func testPoweredOnWithoutSavedIdentifierStartsScan() {
        manager.centralAvailabilityChanged(.poweredOn)
        XCTAssertEqual(central.scanCount, 1)
        XCTAssertEqual(manager.state, .scanning)
        XCTAssertTrue(central.connectRequests.isEmpty)
    }

    func testPoweredOnWithSavedIdentifierConnectsDirectly() {
        let known = FakeHandle(name: "FiiO BTA30 Pro")
        defaults.set(known.id.uuidString, forKey: Preferences.peripheralIdentifier)
        central.knownPeripheral = known

        manager.centralAvailabilityChanged(.poweredOn)

        XCTAssertEqual(central.scanCount, 0, "direct reconnect must skip scanning")
        XCTAssertEqual(central.connectRequests.count, 1)
        XCTAssertTrue(central.connectRequests.first === known)
        XCTAssertEqual(manager.state, .connecting)
    }

    func testAvailabilityMapsToStates() {
        manager.centralAvailabilityChanged(.poweredOff)
        XCTAssertEqual(manager.state, .bluetoothOff)
        manager.centralAvailabilityChanged(.unauthorized)
        XCTAssertEqual(manager.state, .unauthorized)
    }

    // MARK: - Discovery matching

    func testDiscoveryMatchesByName() {
        manager.centralAvailabilityChanged(.poweredOn)
        let device = FakeHandle(name: "FiiO BTA30 Pro")

        manager.centralDiscovered(device, advertisedName: nil, advertisedServices: [])

        XCTAssertEqual(central.stopScanCount, 1)
        XCTAssertTrue(central.connectRequests.first === device)
        XCTAssertEqual(manager.state, .connecting)
    }

    func testDiscoveryIgnoresUnrelatedDevices() {
        manager.centralAvailabilityChanged(.poweredOn)
        manager.centralDiscovered(FakeHandle(name: "AirPods Pro"), advertisedName: nil, advertisedServices: [])
        XCTAssertTrue(central.connectRequests.isEmpty)
        XCTAssertEqual(manager.state, .scanning)
    }

    func testDiscoveryMatchesByAdvertisedGAIAService() {
        manager.centralAvailabilityChanged(.poweredOn)
        let unnamed = FakeHandle(name: nil)
        manager.centralDiscovered(unnamed, advertisedName: nil, advertisedServices: [GAIAService.service])
        XCTAssertTrue(central.connectRequests.first === unnamed)
    }

    func testDiscoveryIgnoredWhenNotScanning() {
        manager.centralAvailabilityChanged(.poweredOn)
        manager.centralDiscovered(FakeHandle(name: "FiiO BTA30 Pro"), advertisedName: nil, advertisedServices: [])
        manager.centralDiscovered(FakeHandle(name: "FiiO BTA30 Pro"), advertisedName: nil, advertisedServices: [])
        XCTAssertEqual(central.connectRequests.count, 1, "only the first match may trigger a connect")
    }

    // MARK: - Connection lifecycle

    func testConnectedPersistsIdentifierAndName() {
        let device = FakeHandle(name: "FiiO BTA30 Pro")
        manager.centralConnected(device)
        XCTAssertEqual(manager.deviceName, "FiiO BTA30 Pro")
        XCTAssertEqual(defaults.string(forKey: Preferences.peripheralIdentifier), device.id.uuidString)
    }

    func testFailedConnectRetriesSearch() {
        manager.centralAvailabilityChanged(.poweredOn)
        XCTAssertEqual(central.scanCount, 1)

        manager.centralFailedToConnect()
        XCTAssertEqual(central.scanCount, 1, "retry must wait for the scheduler")

        retries.fireAll()
        XCTAssertEqual(central.scanCount, 2)
    }

    func testFailedConnectSurfacesIssueAndSuccessClearsIt() {
        manager.centralAvailabilityChanged(.poweredOn)
        manager.centralFailedToConnect()
        XCTAssertEqual(manager.lastIssue, .connectFailed)

        manager.centralConnected(FakeHandle(name: "FiiO BTA30 Pro"))
        XCTAssertNil(manager.lastIssue)
    }

    func testFailedConnectRetrySkippedWhenPoweredOff() {
        manager.centralAvailabilityChanged(.poweredOn)
        manager.centralFailedToConnect()
        central.isPoweredOn = false
        retries.fireAll()
        XCTAssertEqual(central.scanCount, 1)
    }

    func testDisconnectReconnectsAndBlocksActions() {
        let device = FakeHandle(name: "FiiO BTA30 Pro")
        let sink = FrameSink()
        manager.transportDidConnect(sink)
        sink.frames.removeAll()

        manager.centralDisconnected(device)

        XCTAssertEqual(manager.state, .connecting)
        XCTAssertTrue(central.connectRequests.last === device, "must issue a pending reconnect")
        manager.setVolume(30)
        XCTAssertTrue(sink.frames.isEmpty, "no frames may be written after disconnect")
    }
}
