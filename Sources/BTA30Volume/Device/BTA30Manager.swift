import CoreBluetooth
import Foundation
import os.log

/// Mirrors device state and decides how to react to BLE events.
///
/// All CoreBluetooth plumbing lives behind two seams: `BLECentralControlling`
/// (discovery/connection) and `GAIATransport` (frame writes). This class holds
/// the decisions — what to connect to, when to retry, how to interpret GAIA
/// responses — which is exactly what the unit tests drive through fakes.
final class BTA30Manager: ObservableObject {
    enum ConnectionState: Equatable {
        case bluetoothOff
        case unauthorized
        case scanning
        case connecting
        case connected
    }

    static let maxVolume = 60

    /// Ignore device volume/balance pushes this soon after a local change
    /// (they are echoes of our own writes and would make the slider jump).
    private static let remoteEchoWindow: TimeInterval = 0.5
    /// Delay before retrying discovery after a failed connect.
    private static let connectRetryDelay: TimeInterval = 2

    @Published private(set) var state: ConnectionState = .scanning
    @Published private(set) var volume: Int = 0
    @Published var deviceName: String = ""
    @Published private(set) var ledOff: Bool = false
    @Published private(set) var filter: Int = 0
    /// -12 (full left) … 0 (center) … +12 (full right)
    @Published private(set) var balance: Int = 0
    @Published private(set) var upsampling: Bool = false
    @Published private(set) var bootMode: Bool = false
    @Published private(set) var firmwareVersion: String = ""

    var isConnected: Bool { state == .connected }

    private let central: BLECentralControlling?
    private var transport: GAIATransport?

    private let defaults: UserDefaults
    private let volumeWriter: WriteScheduling
    private let balanceWriter: WriteScheduling
    private let resyncWriter: WriteScheduling
    private let now: () -> Date
    private let retryScheduler: (TimeInterval, @escaping () -> Void) -> Void
    private let logger = Logger(category: "device")

    private var lastLocalChangeDate = Date.distantPast
    private var lastBalanceChangeDate = Date.distantPast

    init(
        central: BLECentralControlling? = CoreBluetoothCentral(),
        defaults: UserDefaults = .standard,
        volumeWriter: WriteScheduling = WriteCoalescer(delay: 0.09, immediateInterval: 0.08),
        balanceWriter: WriteScheduling = WriteCoalescer(delay: 0.08),
        resyncWriter: WriteScheduling = WriteCoalescer(delay: 0.3),
        now: @escaping () -> Date = Date.init,
        retryScheduler: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.central = central
        self.defaults = defaults
        self.volumeWriter = volumeWriter
        self.balanceWriter = balanceWriter
        self.resyncWriter = resyncWriter
        self.now = now
        self.retryScheduler = retryScheduler
        central?.events = self
    }

    // MARK: - User actions

    /// Volume flow in a nutshell:
    /// 1. `setVolume` updates `volume` optimistically, stamps
    ///    `lastLocalChangeDate`, then hands the write to `volumeWriter` so a
    ///    slider drag sends at most ~12 writes/second (latest value wins).
    /// 2. The device pushes a `getVolume` notification for every change —
    ///    including echoes of our own writes. `handle(_:)` ignores pushes
    ///    within `remoteEchoWindow` of a local change and clamps anything
    ///    above `volumeLimit`, no matter the source (IR remote included).
    func setVolume(_ value: Int) {
        guard isConnected else { return }
        let clamped = max(0, min(Self.maxVolume, value))
        guard clamped != volume || volumeWriter.hasPending else { return }
        volume = clamped
        lastLocalChangeDate = now()
        volumeWriter.send { [weak self] in
            guard let self else { return }
            self.send(.setVolume, payload: [UInt8(self.volume)])
        }
    }

    func stepVolume(_ delta: Int) {
        setVolume(volume + delta)
    }



    // MARK: - GAIA send/receive

    private func send(_ command: GAIACommand, payload: [UInt8] = []) {
        transport?.send(GAIA.request(command, payload: payload))
    }

    private func requestDeviceState() {
        send(.getVolume)
        send(.getLedMode)
        send(.getFilter)
        send(.getBalance)
        send(.getUpsampling)
        send(.getBootMode)
        send(.getVersion)
    }

    private func handle(_ response: GAIA.Response) {
        let payload = response.payload
        switch GAIACommand(rawValue: response.commandID) {
        case .getVolume:
            guard let value = payload.first else { return }
            if now().timeIntervalSince(lastLocalChangeDate) > Self.remoteEchoWindow {
                let incoming = Int(value)
                    volume = incoming
            }
        case .getLedMode:
            guard let value = payload.first else { return }
            ledOff = value == 0x00
        case .getFilter:
            guard let value = payload.first else { return }
            filter = Int(value)
        case .getBalance:
            guard payload.count >= 2 else { return }
            if now().timeIntervalSince(lastBalanceChangeDate) > Self.remoteEchoWindow {
                let amount = Int(payload[1])
                balance = payload[0] == 0x01 ? -amount : amount
            }
        case .getUpsampling:
            upsampling = payload.first == 0x01
        case .getBootMode:
            bootMode = payload.first == 0x01
        case .getVersion:
            guard payload.count >= 2 else { return }
            firmwareVersion = "v\(payload[0]).\(payload[1])"
        default:
            break
        }
    }

    // MARK: - Connection flow

    private func startSearching() {
        guard let central else { return }
        state = .scanning
        // If we connected before, try connecting directly (works even if renamed)
        if let idString = defaults.string(forKey: Preferences.peripheralIdentifier),
           let id = UUID(uuidString: idString),
           let known = central.retrieveKnown(id: id) {
            state = .connecting
            central.connect(known)
            return
        }
        // The device does not advertise the GAIA service; scan everything and match by name
        central.scanAll()
    }
}

// MARK: - BLECentralEvents

extension BTA30Manager: BLECentralEvents {
    func centralAvailabilityChanged(_ availability: CentralAvailability) {
        switch availability {
        case .poweredOn: startSearching()
        case .poweredOff: state = .bluetoothOff
        case .unauthorized: state = .unauthorized
        case .other: break
        }
    }

    func centralDiscovered(_ peripheral: BLEPeripheralHandle, advertisedName: String?, advertisedServices: [CBUUID]) {
        guard state == .scanning else { return }
        let name = peripheral.peripheralName ?? advertisedName ?? ""
        guard name.uppercased().contains("BTA30") || advertisedServices.contains(GAIAService.service) else { return }
        central?.stopScan()
        state = .connecting
        central?.connect(peripheral)
    }

    func centralConnected(_ peripheral: BLEPeripheralHandle) {
        deviceName = peripheral.peripheralName ?? "FiiO BTA30 Pro"
        defaults.set(peripheral.id.uuidString, forKey: Preferences.peripheralIdentifier)
    }

    func centralFailedToConnect() {
        retryScheduler(Self.connectRetryDelay) { [weak self] in
            guard let self, self.central?.isPoweredOn == true, !self.isConnected else { return }
            self.startSearching()
        }
    }

    func centralDisconnected(_ peripheral: BLEPeripheralHandle) {
        transportDidDisconnect()
        guard central?.isPoweredOn == true else { return }
        // The pending connect request completes automatically once the device returns
        state = .connecting
        central?.connect(peripheral)
    }

    func transportDidConnect(_ transport: GAIATransport) {
        self.transport = transport
        state = .connected
        requestDeviceState()
    }

    func receive(_ data: Data) {
        guard let response = GAIA.parseResponse(data) else { return }
        handle(response)
    }

    /// A write was rejected by the device or the BLE stack: log it and re-read
    /// the device state so the optimistic UI converges with reality. Failures
    /// in quick succession coalesce into a single resync.
    func writeDidFail(_ error: Error) {
        logger.error("GAIA write failed: \(error.localizedDescription, privacy: .public)")
        resyncWriter.send { [weak self] in
            self?.requestDeviceState()
        }
    }
}

// MARK: - Test hooks

extension BTA30Manager {
    /// Marks the transport gone. Split out of `centralDisconnected` so tests
    /// without a central can simulate connection loss.
    func transportDidDisconnect() {
        transport = nil
        if state == .connected {
            state = .connecting
        }
    }
}
