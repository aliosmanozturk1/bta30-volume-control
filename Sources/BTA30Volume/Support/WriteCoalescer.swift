import Foundation

/// Anything that can schedule a write action. Production code uses
/// `WriteCoalescer`; tests substitute a synchronous scheduler.
protocol WriteScheduling: AnyObject {
    var hasPending: Bool { get }
    func send(_ action: @escaping () -> Void)
}

/// Rate-limits BLE writes while a slider is being dragged.
///
/// Each `send` supersedes the pending write, so only the latest value reaches
/// the device. When `immediateInterval` is set and that much time has passed
/// since the last write, the action fires right away so the first movement of
/// a drag feels instant. The clock and the scheduler are injectable so the
/// timing logic itself is unit-testable.
final class WriteCoalescer: WriteScheduling {
    private let delay: TimeInterval
    private let immediateInterval: TimeInterval?
    private let now: () -> Date
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void

    private var lastFireDate = Date.distantPast
    private var generation = 0
    private var pendingGeneration: Int?

    init(
        delay: TimeInterval,
        immediateInterval: TimeInterval? = nil,
        now: @escaping () -> Date = Date.init,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.delay = delay
        self.immediateInterval = immediateInterval
        self.now = now
        self.schedule = schedule
    }

    var hasPending: Bool { pendingGeneration != nil }

    func send(_ action: @escaping () -> Void) {
        generation += 1
        if let immediateInterval, now().timeIntervalSince(lastFireDate) > immediateInterval {
            pendingGeneration = nil
            lastFireDate = now()
            action()
            return
        }
        let scheduledGeneration = generation
        pendingGeneration = scheduledGeneration
        schedule(delay) { [weak self] in
            guard let self, self.pendingGeneration == scheduledGeneration else { return }
            self.pendingGeneration = nil
            self.lastFireDate = self.now()
            action()
        }
    }
}
