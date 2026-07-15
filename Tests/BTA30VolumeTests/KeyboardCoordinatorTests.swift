import AppKit
import Carbon
import XCTest
@testable import BTA30Volume

/// Persistence and shortcut-recording rules. Media-key/Carbon side effects
/// stay off because both toggles default to false with a clean defaults suite.
final class KeyboardCoordinatorTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var coordinator: KeyboardCoordinator!

    override func setUp() {
        super.setUp()
        suiteName = "test.bta30.keyboard.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        coordinator = KeyboardCoordinator(defaults: defaults)
    }

    override func tearDown() {
        coordinator.endRecording()
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func keyDown(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: "x",
            charactersIgnoringModifiers: "x", isARepeat: false, keyCode: keyCode
        )!
    }

    // MARK: - Persistence

    func testKeyStepRoundTripsThroughDefaults() {
        coordinator.keyStep = 3
        let reloaded = KeyboardCoordinator(defaults: defaults)
        XCTAssertEqual(reloaded.keyStep, 3)
    }

    func testInvalidSavedKeyStepFallsBackToDefault() {
        defaults.set(9, forKey: Preferences.keyStep)
        let reloaded = KeyboardCoordinator(defaults: defaults)
        XCTAssertEqual(reloaded.keyStep, 2)
    }

    func testFreshCoordinatorUsesDefaultBindings() {
        XCTAssertEqual(coordinator.hotKeyBindings, HotKeyAction.defaultBindings)
    }

    // MARK: - Shortcut recording

    func testRecordingAssignsBindingAndPersists() {
        coordinator.beginRecording(.mute)
        let result = coordinator.handleRecordingKeyDown(
            keyDown(keyCode: UInt16(kVK_Space), flags: [.control, .command]))

        XCTAssertNil(result, "the recorded key-down must be swallowed")
        XCTAssertNil(coordinator.recordingAction, "recording must end after a successful capture")
        let expected = HotKeySpec(
            keyCode: UInt32(kVK_Space),
            modifierFlags: NSEvent.ModifierFlags([.control, .command]).rawValue)
        XCTAssertEqual(coordinator.hotKeyBindings[.mute], expected)

        let reloaded = KeyboardCoordinator(defaults: defaults)
        XCTAssertEqual(reloaded.hotKeyBindings[.mute], expected)
    }

    func testEscapeCancelsRecordingWithoutChanges() {
        let before = coordinator.hotKeyBindings
        coordinator.beginRecording(.mute)
        _ = coordinator.handleRecordingKeyDown(keyDown(keyCode: 53, flags: []))
        XCTAssertNil(coordinator.recordingAction)
        XCTAssertEqual(coordinator.hotKeyBindings, before)
    }

    func testBareKeyIsRejectedWithHint() {
        coordinator.beginRecording(.mute)
        _ = coordinator.handleRecordingKeyDown(keyDown(keyCode: UInt16(kVK_ANSI_A), flags: []))
        XCTAssertNotNil(coordinator.hotKeyHint)
        XCTAssertEqual(coordinator.recordingAction, .mute, "recording must stay active after a rejection")
    }

    func testDuplicateComboIsRejected() {
        // volumeUp's default is ⌥⌘↑ — try assigning the same combo to mute
        coordinator.beginRecording(.mute)
        _ = coordinator.handleRecordingKeyDown(
            keyDown(keyCode: UInt16(kVK_UpArrow), flags: [.option, .command]))
        XCTAssertNotNil(coordinator.hotKeyHint)
        XCTAssertEqual(coordinator.recordingAction, .mute)
        XCTAssertEqual(coordinator.hotKeyBindings[.mute], HotKeyAction.mute.defaultSpec)
    }

    func testResetRestoresDefaultBindings() {
        coordinator.beginRecording(.mute)
        _ = coordinator.handleRecordingKeyDown(
            keyDown(keyCode: UInt16(kVK_Space), flags: [.control, .command]))
        coordinator.resetHotKeys()
        XCTAssertEqual(coordinator.hotKeyBindings, HotKeyAction.defaultBindings)
    }
}
