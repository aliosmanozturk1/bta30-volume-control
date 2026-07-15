import XCTest
@testable import BTA30Volume

/// Captures scheduled work so tests decide when timers "fire".
private final class ManualScheduler {
    var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
    func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        scheduled.append((delay, work))
    }
    func fireAll() {
        let works = scheduled
        scheduled = []
        works.forEach { $0.work() }
    }
}

private final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class WriteCoalescerTests: XCTestCase {
    private var clock: TestClock!
    private var scheduler: ManualScheduler!

    override func setUp() {
        super.setUp()
        clock = TestClock()
        scheduler = ManualScheduler()
    }

    private func makeCoalescer(delay: TimeInterval = 0.1, immediateInterval: TimeInterval? = nil) -> WriteCoalescer {
        let clock = self.clock!
        let scheduler = self.scheduler!
        return WriteCoalescer(
            delay: delay,
            immediateInterval: immediateInterval,
            now: { clock.now },
            schedule: { delay, work in scheduler.schedule(delay, work) }
        )
    }

    func testRapidSendsCoalesceToLatestAction() {
        let coalescer = makeCoalescer()
        var fired: [Int] = []

        coalescer.send { fired.append(1) }
        coalescer.send { fired.append(2) }
        coalescer.send { fired.append(3) }
        XCTAssertTrue(coalescer.hasPending)

        scheduler.fireAll()

        XCTAssertEqual(fired, [3], "superseded writes must never fire; only the latest wins")
        XCTAssertFalse(coalescer.hasPending)
    }

    func testScheduledWorkUsesConfiguredDelay() {
        let coalescer = makeCoalescer(delay: 0.09)
        coalescer.send {}
        XCTAssertEqual(scheduler.scheduled.first?.delay, 0.09)
    }

    func testImmediateFastPathFiresWithoutScheduling() {
        let coalescer = makeCoalescer(immediateInterval: 0.08)
        var fired = 0

        // Enough time since the last fire (distantPast) → fires immediately
        coalescer.send { fired += 1 }
        XCTAssertEqual(fired, 1)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertFalse(coalescer.hasPending)
    }

    func testSendWithinImmediateIntervalGetsScheduled() {
        let coalescer = makeCoalescer(immediateInterval: 0.08)
        var fired: [String] = []

        coalescer.send { fired.append("first") }        // immediate
        coalescer.send { fired.append("second") }       // same instant: falls to trailing
        XCTAssertEqual(fired, ["first"])
        XCTAssertTrue(coalescer.hasPending)

        scheduler.fireAll()
        XCTAssertEqual(fired, ["first", "second"])

        // The trailing fire updates lastFireDate; once enough time passes,
        // the fast path opens up again
        clock.advance(0.2)
        coalescer.send { fired.append("third") }
        XCTAssertEqual(fired, ["first", "second", "third"])
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    func testStaleScheduledWorkIsANoOpAfterImmediateFire() {
        let coalescer = makeCoalescer(immediateInterval: 0.08)
        var fired: [String] = []

        coalescer.send { fired.append("immediate-1") }  // immediate
        coalescer.send { fired.append("trailing") }     // scheduled
        clock.advance(0.2)
        coalescer.send { fired.append("immediate-2") }  // fast path; supersedes the trailing work

        scheduler.fireAll()
        XCTAssertEqual(fired, ["immediate-1", "immediate-2"], "superseded trailing work must not fire")
    }
}
