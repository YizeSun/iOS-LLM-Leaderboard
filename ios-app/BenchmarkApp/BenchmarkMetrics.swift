import Foundation

struct AttemptMetrics: Codable, Sendable, Equatable {
    let ttftMilliseconds: Double?
    let prefillTokensPerSecond: Double?
    let decodeTokensPerSecond: Double?
    let peakMemoryMegabytes: Double?
    let p50TokenIntervalMilliseconds: Double?
    let p95TokenIntervalMilliseconds: Double?
    let p99TokenIntervalMilliseconds: Double?

    static func calculate(for attempt: BenchmarkAttempt) -> AttemptMetrics {
        let intervals = zip(attempt.tokens, attempt.tokens.dropFirst()).map {
            Double($1.elapsedNanoseconds - $0.elapsedNanoseconds) / 1_000_000
        }

        let generation: RuntimeGenerationResult?
        if case .completed(let value) = attempt.outcome {
            generation = value
        } else {
            generation = nil
        }

        let decode: Double?
        if let first = attempt.tokens.first,
           let last = attempt.tokens.last,
           attempt.tokens.count > 1,
           last.elapsedNanoseconds > first.elapsedNanoseconds {
            let seconds = Double(last.elapsedNanoseconds - first.elapsedNanoseconds)
                / 1_000_000_000
            decode = Double(attempt.tokens.count - 1) / seconds
        } else {
            decode = nil
        }

        let prefill: Double?
        if let generation,
           let seconds = generation.promptTimeSeconds,
           seconds > 0 {
            prefill = Double(generation.promptTokenCount) / seconds
        } else {
            prefill = nil
        }

        return AttemptMetrics(
            ttftMilliseconds: attempt.tokens.first.map {
                Double($0.elapsedNanoseconds) / 1_000_000
            },
            prefillTokensPerSecond: prefill,
            decodeTokensPerSecond: decode,
            peakMemoryMegabytes: attempt.peakMemoryBytes.map {
                Double($0) / 1_048_576
            },
            p50TokenIntervalMilliseconds: percentile(intervals, 0.50),
            p95TokenIntervalMilliseconds: percentile(intervals, 0.95),
            p99TokenIntervalMilliseconds: percentile(intervals, 0.99)
        )
    }

    static func median(_ values: [Double?]) -> Double? {
        percentile(values.compactMap { $0 }, 0.50)
    }

    private static func percentile(_ values: [Double], _ percentile: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = percentile * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard lower != upper else { return sorted[lower] }
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }
}
