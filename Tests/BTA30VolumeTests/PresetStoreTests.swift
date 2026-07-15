import XCTest
@testable import BTA30Volume

final class PresetStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.bta30.presets.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makePreset(name: String, volume: Int = 20) -> Preset {
        Preset(name: name, volume: volume, filter: 1, ledOff: true, balance: -2, upsampling: false)
    }

    func testSaveAndReloadRoundTrip() {
        let store = PresetStore(defaults: defaults)
        store.saveOrUpdate(makePreset(name: "Night", volume: 15))

        let reloaded = PresetStore(defaults: defaults)
        XCTAssertEqual(reloaded.presets.count, 1)
        XCTAssertEqual(reloaded.presets.first?.name, "Night")
        XCTAssertEqual(reloaded.presets.first?.volume, 15)
        XCTAssertEqual(reloaded.presets.first?.balance, -2)
    }

    func testSaveWithSameNameOverwritesKeepingIdentity() {
        let store = PresetStore(defaults: defaults)
        store.saveOrUpdate(makePreset(name: "Night", volume: 15))
        let originalID = store.presets[0].id

        store.saveOrUpdate(makePreset(name: "night", volume: 30))

        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.presets[0].id, originalID)
        XCTAssertEqual(store.presets[0].volume, 30)
    }

    func testDelete() {
        let store = PresetStore(defaults: defaults)
        store.saveOrUpdate(makePreset(name: "Night"))
        store.saveOrUpdate(makePreset(name: "Day"))

        store.delete(store.presets[0])

        XCTAssertEqual(store.presets.map(\.name), ["Day"])
    }

    func testFindNamedIsCaseAndDiacriticInsensitive() {
        let store = PresetStore(defaults: defaults)
        store.saveOrUpdate(makePreset(name: "Café"))

        XCTAssertNotNil(store.find(named: "café"))
        XCTAssertNotNil(store.find(named: "cafe"))
        XCTAssertNil(store.find(named: "night"))
    }

    func testSaveMatchingIsAsLooseAsLookupMatching() {
        // If "Café" and "cafe" were two separate presets, the URL lookup could resolve the wrong one
        let store = PresetStore(defaults: defaults)
        store.saveOrUpdate(makePreset(name: "Café", volume: 15))
        let originalID = store.presets[0].id

        store.saveOrUpdate(makePreset(name: "cafe", volume: 30))

        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.presets[0].id, originalID)
        XCTAssertEqual(store.presets[0].volume, 30)
    }
}
