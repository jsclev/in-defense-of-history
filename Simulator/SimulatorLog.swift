import OSLog

/// Diagnostics only: Apple's unified log owns filtering, privacy and retention.
/// Keep Logger calls at their call sites so interpolation stays lazy and typed.
/// This namespace never writes to stdout (reserved for the worker JSON protocol).
enum SimulatorLog {
    static let subsystem = Constants.appIdentifier + ".simulator"
    static let cli = Logger(subsystem: subsystem, category: "CLI")
    static let database = Logger(subsystem: subsystem, category: "Database")
    static let ga = Logger(subsystem: subsystem, category: "GA")
    static let worker = Logger(subsystem: subsystem, category: "Worker")
    static let study = Logger(subsystem: subsystem, category: "Study")
}
