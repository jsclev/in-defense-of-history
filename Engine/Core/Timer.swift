#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class Timer {

    public private(set) var tickDuration: Duration

    public private(set) var tick: Int64 = 0

    public var spinWindow: Duration = .microseconds(500)

    private let clock: ContinuousClock
    private var origin: ContinuousClock.Instant
    private var anchorTick: Int64 = 0

    public init(tickDuration: Duration) {
        precondition(tickDuration >= .zero, "tickDuration must be non-negative")
        self.tickDuration = tickDuration
        let clock = ContinuousClock()
        self.clock = clock
        self.origin = clock.now
    }

    public var isUnbounded: Bool { tickDuration == .zero }

    public func deadline(forTick n: Int64) -> ContinuousClock.Instant {
        origin.advanced(by: tickDuration * Int(n - anchorTick))
    }

    public var currentLag: Duration {
        guard !isUnbounded else { return .zero }
        let due = deadline(forTick: tick)
        let now = clock.now
        return now > due ? due.duration(to: now) : .zero
    }

    @discardableResult
    public func waitForNextTick() -> Int64 {
        tick &+= 1
        if !isUnbounded {
            waitPrecisely(until: deadline(forTick: tick))
        }
        return tick
    }

    public func dueTicks(maxCatchUp: Int = 8) -> Int {
        guard !isUnbounded else { return 1 }
        let elapsed = origin.duration(to: clock.now) / tickDuration
        let target = anchorTick &+ Int64(elapsed.rounded(.down))
        let due = max(Int64(0), target - tick)
        return Int(min(due, Int64(maxCatchUp)))
    }

    @discardableResult
    public func advanceTick() -> Int64 {
        tick &+= 1
        return tick
    }

    public var interpolationAlpha: Double {
        guard !isUnbounded else { return 1 }
        let f = origin.duration(to: clock.now) / tickDuration
        let frac = f - f.rounded(.down)
        return min(max(frac, 0), 1)
    }

    public func resync() {
        origin = clock.now
        anchorTick = tick
    }

    public func setTickDuration(_ newValue: Duration) {
        precondition(newValue >= .zero, "tickDuration must be non-negative")
        resync()
        tickDuration = newValue
    }

    private func waitPrecisely(until deadline: ContinuousClock.Instant) {
        while true {
            let now = clock.now
            if now >= deadline { return }
            let remaining = now.duration(to: deadline)
            if remaining > spinWindow {
                coarseSleep(remaining - spinWindow)
            } else {
                while clock.now < deadline { }
                return
            }
        }
    }

    private func coarseSleep(_ d: Duration) {
        let ns = Self.nanoseconds(of: d)
        guard ns > 0 else { return }
        #if canImport(Darwin)
        mach_wait_until(mach_absolute_time() &+ MachTime.ticks(fromNanoseconds: ns))
        #elseif canImport(Glibc)
        var ts = timespec(tv_sec: Int(ns / 1_000_000_000),
                          tv_nsec: Int(ns % 1_000_000_000))
        nanosleep(&ts, nil)
        #endif
    }

    private static func nanoseconds(of d: Duration) -> UInt64 {
        guard d > .zero else { return 0 }
        let c = d.components
        return UInt64(c.seconds) &* 1_000_000_000 &+ UInt64(c.attoseconds / 1_000_000_000)
    }

    #if canImport(Darwin)
    @discardableResult
    public static func promoteCurrentThreadToRealTime(
        expectedTick: Duration,
        computation: Duration = .milliseconds(2),
        constraint: Duration? = nil
    ) -> Bool {
        let periodTicks = MachTime.ticks(fromNanoseconds: nanoseconds(of: expectedTick))
        let compTicks = MachTime.ticks(fromNanoseconds: nanoseconds(of: computation))
        let consTicks = MachTime.ticks(fromNanoseconds: nanoseconds(of: constraint ?? expectedTick / 2))

        var policy = thread_time_constraint_policy(
            period: UInt32(clamping: periodTicks),
            computation: UInt32(clamping: compTicks),
            constraint: UInt32(clamping: consTicks),
            preemptible: 1
        )
        let count = mach_msg_type_number_t(
            MemoryLayout<thread_time_constraint_policy>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &policy) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                thread_policy_set(
                    pthread_mach_thread_np(pthread_self()),
                    thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY),
                    intPtr,
                    count
                )
            }
        }
        return result == KERN_SUCCESS
    }
    #endif
}

#if canImport(Darwin)
private enum MachTime {
    static let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t(numer: 0, denom: 0)
        mach_timebase_info(&tb)
        return tb
    }()

    static func ticks(fromNanoseconds ns: UInt64) -> UInt64 {
        let full = ns.multipliedFullWidth(by: UInt64(timebase.denom))
        return UInt64(timebase.numer).dividingFullWidth(full).quotient
    }
}
#endif
