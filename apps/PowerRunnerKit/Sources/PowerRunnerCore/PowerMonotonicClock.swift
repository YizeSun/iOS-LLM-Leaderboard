import Foundation

public protocol PowerMonotonicClock: Sendable {
    func nowNanoseconds() -> UInt64
}
public struct ContinuousPowerMonotonicClock: PowerMonotonicClock {
    private let origin: ContinuousClock.Instant

    public init() {
        origin = .now
    }

    public func nowNanoseconds() -> UInt64 {
        origin.duration(to: .now).nonnegativeNanoseconds
    }
}

private extension Duration {
    var nonnegativeNanoseconds: UInt64 {
        let value = components
        guard value.seconds >= 0, value.attoseconds >= 0 else {
            return 0
        }
        let seconds = UInt64(value.seconds)
        let nanoseconds = UInt64(value.attoseconds / 1_000_000_000)
        let (whole, overflow) = seconds.multipliedReportingOverflow(
            by: 1_000_000_000
        )
        guard !overflow else { return UInt64.max }
        let (result, additionOverflow) = whole.addingReportingOverflow(
            nanoseconds
        )
        return additionOverflow ? UInt64.max : result
    }
}
