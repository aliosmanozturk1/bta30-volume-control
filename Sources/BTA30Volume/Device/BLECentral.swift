import CoreBluetooth
import Foundation

/// GATT identifiers of the BTA30's GAIA service.
enum GAIAService {
    static let service = CBUUID(string: "00001100-D102-11E1-9B23-00025B00A5A5")
    static let commandCharacteristic = CBUUID(string: "00001101-D102-11E1-9B23-00025B00A5A5")
    static let responseCharacteristic = CBUUID(string: "00001102-D102-11E1-9B23-00025B00A5A5")
}

/// Bluetooth availability as reported by the central.
enum CentralAvailability {
    case poweredOn
    case poweredOff
    case unauthorized
    case other
}

/// Opaque reference to a discovered peripheral.
protocol BLEPeripheralHandle: AnyObject {
    var id: UUID { get }
    var peripheralName: String? { get }
}

/// The seam over CBCentralManager, mirroring the `GAIATransport` pattern.
/// Production uses `CoreBluetoothCentral`; tests substitute a fake so the
/// discovery/connect/reconnect logic in `BTA30Manager` can be unit tested.
protocol BLECentralControlling: AnyObject {
    var events: BLECentralEvents? { get set }
    var isPoweredOn: Bool { get }
    func scanAll()
    func stopScan()
    func connect(_ peripheral: BLEPeripheralHandle)
    func retrieveKnown(id: UUID) -> BLEPeripheralHandle?
}

/// Events the central reports back to its owner.
protocol BLECentralEvents: AnyObject {
    func centralAvailabilityChanged(_ availability: CentralAvailability)
    func centralDiscovered(_ peripheral: BLEPeripheralHandle, advertisedName: String?, advertisedServices: [CBUUID])
    func centralConnected(_ peripheral: BLEPeripheralHandle)
    func centralFailedToConnect()
    func centralDisconnected(_ peripheral: BLEPeripheralHandle)
    func transportDidConnect(_ transport: GAIATransport)
    func receive(_ data: Data)
    func writeDidFail(_ error: Error)
}
