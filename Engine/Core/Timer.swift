//
//  Timer.swift
//  RevolutionEngine
//
//  The engine's global coordination clock: a step machine whose real-time
//  pacing is supplied at construction.
//
//  Design:
//    - `tickDuration` is the amount of actual time each tick represents.
//      `.zero` means UNBOUNDED: no clock is consulted, ticks run as fast as
//      the CPU can execute them (batch simulation mode).
//    - Simulation time is the integer `tick` counter. All game systems sync
//      against `tick`, never against wall time.
//    - Deadlines are computed from an origin as `origin + n * tickDuration`
//      in 128-bit Duration math (attosecond representation). Errors are
//      bounded per tick and NEVER accumulate. This matters because 1/30 s
//      is not a whole number of nanoseconds.
//    - Paced waits use a two-phase strategy: a coarse absolute-deadline
//      sleep (`mach_wait_until` on Darwin), then a short spin on the
//      monotonic clock for sub-microsecond arrival.
//
//  Pure Swift standard library at the core (no Foundation), so this file
//  drops into the dependency-free engine target. Inside that module the
//  name `Timer` is unambiguous; app-layer code that also imports Foundation
//  should reference it as `RevolutionEngine.Timer`.
//
//  Not Sendable by design: one Timer instance belongs to one driving thread.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class Timer {

    // MARK: - State

    /// Actual time represented by one tick. `.zero` = unbounded.
    public private(set) var tickDuration: Duration

    /// Authoritative simulation time. Everything in the game syncs to this.
    public private(set) var tick: Int64 = 0

    /// Size of the final busy-wait window in paced mode. Larger = more
    /// CPU burned per tick, tighter arrival. 500 µs is a good default on
    /// a real-time-promoted thread; raise it on a default-priority thread.
    public var spinWindow: Duration = .microseconds(500)

    private let clock: ContinuousClock
    private var origin: ContinuousClock.Instant
    private var anchorTick: Int64 = 0

    // MARK: - Init

    /// - Parameter tickDuration: actual time per tick. Examples:
    ///   `.seconds(1) / 30` for normal play, `.seconds(1) / 60` for 2x
    ///   fast-forward, `.zero` for flat-out headless simulation.
    public init(tickDuration: Duration) {
        precondition(tickDuration >= .zero, "tickDuration must be non-negative")
        self.tickDuration = tickDuration
        let clock = ContinuousClock()
        self.clock = clock
        self.origin = clock.now
    }

    public var isUnbounded: Bool { tickDuration == .zero }

    // MARK: - Schedule (drift-free by construction)

    /// The wall-clock instant at which tick `n` is due. Always computed
    /// from the origin — never accumulated — so scheduling error is
    /// bounded (< 1 ns + hardware granularity) and non-cumulative.
    public func deadline(forTick n: Int64) -> ContinuousClock.Instant {
        origin.advanced(by: tickDuration * Int(n - anchorTick))
    }

    /// How far behind schedule the just-completed tick ran. Diagnostic.
    public var currentLag: Duration {
        guard !isUnbounded else { return .zero }
        let due = deadline(forTick: tick)
        let now = clock.now
        return now > due ? due.duration(to: now) : .zero
    }

    // MARK: - Blocking driver (headless CLI, dedicated sim thread)

    /// Advances to the next tick, blocking until it is due. In unbounded
    /// mode this returns immediately — the fastest timer is no timer.
    /// If the schedule has slipped (a step overran), it returns immediately
    /// until the schedule is regained: natural catch-up.
    ///
    ///     while !sim.isResolved {
    ///         sim.step(tick: timer.waitForNextTick())
    ///     }
    @discardableResult
    public func waitForNextTick() -> Int64 {
        tick &+= 1
        if !isUnbounded {
            waitPrecisely(until: deadline(forTick: tick))
        }
        return tick
    }

    // MARK: - Callback driver (CAMetalDisplayLink / render loop)

    /// Number of ticks due right now, clamped to `maxCatchUp` to prevent a
    /// long stall (backgrounding, debugger) from triggering a catch-up
    /// avalanche. Call once per frame; run `advanceTick()`-labelled steps:
    ///
    ///     for _ in 0..<timer.dueTicks() { engine.step(tick: timer.advanceTick()) }
    ///     renderer.draw(alpha: timer.interpolationAlpha)
    public func dueTicks(maxCatchUp: Int = 8) -> Int {
        guard !isUnbounded else { return 1 }
        let elapsed = origin.duration(to: clock.now) / tickDuration   // Double
        let target = anchorTick &+ Int64(elapsed.rounded(.down))
        let due = max(Int64(0), target - tick)
        return Int(min(due, Int64(maxCatchUp)))
    }

    /// Manually advance one tick (pairs with `dueTicks`).
    @discardableResult
    public func advanceTick() -> Int64 {
        tick &+= 1
        return tick
    }

    /// Fraction [0, 1) of the way from the current tick to the next, for
    /// render interpolation between simulation snapshots.
    public var interpolationAlpha: Double {
        guard !isUnbounded else { return 1 }
        let f = origin.duration(to: clock.now) / tickDuration
        let frac = f - f.rounded(.down)
        return min(max(frac, 0), 1)
    }

    // MARK: - Control

    /// Re-anchor the schedule at the current instant without disturbing the
    /// tick counter. Call after app foregrounding / long pauses so the
    /// timer resumes cleanly instead of sprinting through missed time.
    public func resync() {
        origin = clock.now
        anchorTick = tick
    }

    /// Change pacing live (fast-forward button, returning from menus).
    /// Simulation outcomes are unaffected by construction: same ticks,
    /// different real-time spacing.
    public func setTickDuration(_ newValue: Duration) {
        precondition(newValue >= .zero, "tickDuration must be non-negative")
        resync()
        tickDuration = newValue
    }

    // MARK: - Precise waiting

    /// Two-phase wait: coarse absolute-deadline sleep to (deadline − spinWindow),
    /// then busy-poll the monotonic clock. Arrival is typically within ~1 µs
    /// of the deadline on a real-time-promoted thread.
    private func waitPrecisely(until deadline: ContinuousClock.Instant) {
        while true {
            let now = clock.now
            if now >= deadline { return }
            let remaining = now.duration(to: deadline)
            if remaining > spinWindow {
                coarseSleep(remaining - spinWindow)
            } else {
                while clock.now < deadline { /* spin: ~41.7 ns per clock read */ }
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

    // MARK: - Real-time thread promotion (Darwin)

    #if canImport(Darwin)
    /// Promote the calling thread to the real-time scheduling class
    /// (THREAD_TIME_CONSTRAINT_POLICY — the same class Core Audio uses),
    /// dramatically tightening `mach_wait_until` wakeups (typically to
    /// tens of microseconds). Call once from the thread that will drive a
    /// paced Timer. Returns true on success.
    ///
    /// - Parameters:
    ///   - expectedTick: the pacing period (e.g. `.seconds(1) / 30`).
    ///   - computation: CPU time actually needed per period (your measured
    ///     sim-step cost, with margin). Keep honest: overclaiming real-time
    ///     budget can get the policy revoked by the scheduler.
    ///   - constraint: max window in which that computation must finish.
    ///     Defaults to half the period.
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

// MARK: - Mach timebase conversion

#if canImport(Darwin)
private enum MachTime {
    static let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t(numer: 0, denom: 0)
        mach_timebase_info(&tb)
        return tb
    }()

    /// Nanoseconds → Mach ticks with 128-bit intermediate math
    /// (ticks = ns * denom / numer; 125/3 timebase on Apple Silicon).
    static func ticks(fromNanoseconds ns: UInt64) -> UInt64 {
        let full = ns.multipliedFullWidth(by: UInt64(timebase.denom))
        return UInt64(timebase.numer).dividingFullWidth(full).quotient
    }
}
#endif
