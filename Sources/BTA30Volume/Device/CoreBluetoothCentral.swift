import CoreBluetooth
import Foundation

/// The real `BLECentralControlling`: owns CBCentralManager, performs the GATT
/// discovery/subscribe dance and translates every CoreBluetooth callback into
/// a `BLECentralEvents` call. Contains no business logic — decisions about
/// what to connect to and how to react live in `BTA30Manager`.
final class CoreBluetoothCentral: NSObject, BLECentralControlling {
    weak var events: BLECentralEvents?

    private var central: CBCentralManager!
    /// CoreBluetooth requires a strong reference to the peripheral for the
    /// lifetime of the connection.
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?

    /// Wraps a CBPeripheral as an opaque handle for the manager.
    private final class Handle: BLEPeripheralHandle {
        let peripheral: CBPeripheral
        var id: UUID { peripheral.identifier }
        var peripheralName: String? { peripheral.name }
        init(_ peripheral: CBPeripheral) { self.peripheral = peripheral }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var isPoweredOn: Bool { central.state == .poweredOn }

    func scanAll() {
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScan() {
        central.stopScan()
    }

    func connect(_ handle: BLEPeripheralHandle) {
        guard let handle = handle as? Handle else { return }
        peripheral = handle.peripheral
        handle.peripheral.delegate = self
        central.connect(handle.peripheral, options: nil)
    }

    func retrieveKnown(id: UUID) -> BLEPeripheralHandle? {
        central.retrievePeripherals(withIdentifiers: [id]).first.map(Handle.init)
    }
}

// MARK: - CBCentralManagerDelegate

extension CoreBluetoothCentral: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: events?.centralAvailabilityChanged(.poweredOn)
        case .poweredOff: events?.centralAvailabilityChanged(.poweredOff)
        case .unauthorized: events?.centralAvailabilityChanged(.unauthorized)
        default: events?.centralAvailabilityChanged(.other)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover discovered: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        events?.centralDiscovered(
            Handle(discovered),
            advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String,
            advertisedServices: advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        )
    }

    func centralManager(_ central: CBCentralManager, didConnect connected: CBPeripheral) {
        events?.centralConnected(Handle(connected))
        connected.discoverServices([GAIAService.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect failed: CBPeripheral, error: Error?) {
        events?.centralFailedToConnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral disconnected: CBPeripheral, error: Error?) {
        commandCharacteristic = nil
        events?.centralDisconnected(Handle(disconnected))
    }
}

// MARK: - CBPeripheralDelegate

extension CoreBluetoothCentral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == GAIAService.service }) else { return }
        peripheral.discoverCharacteristics(
            [GAIAService.commandCharacteristic, GAIAService.responseCharacteristic],
            for: service
        )
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == GAIAService.commandCharacteristic {
                commandCharacteristic = characteristic
            }
            if characteristic.uuid == GAIAService.responseCharacteristic {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == GAIAService.responseCharacteristic,
              let commandCharacteristic else { return }
        events?.transportDidConnect(PeripheralTransport(peripheral: peripheral, characteristic: commandCharacteristic))
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            events?.writeDidFail(error)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        events?.receive(data)
    }
}
