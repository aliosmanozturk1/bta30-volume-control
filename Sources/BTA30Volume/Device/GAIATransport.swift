import CoreBluetooth
import Foundation

/// The seam through which `BTA30Manager` sends GAIA frames. Production uses
/// `PeripheralTransport`; tests substitute a frame-capturing fake.
protocol GAIATransport: AnyObject {
    func send(_ data: Data)
}

/// Real transport: writes to the discovered GAIA command characteristic.
final class PeripheralTransport: GAIATransport {
    private let peripheral: CBPeripheral
    private let characteristic: CBCharacteristic

    init(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        self.peripheral = peripheral
        self.characteristic = characteristic
    }

    func send(_ data: Data) {
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}
