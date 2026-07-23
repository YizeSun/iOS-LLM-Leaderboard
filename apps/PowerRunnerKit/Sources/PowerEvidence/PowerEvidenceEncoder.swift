import Foundation

public enum PowerEvidenceEncodingError: Error, Sendable, Equatable {
    case nonFiniteNumber
}
public enum PowerEvidenceEncoder {
    /// Produces the exact raw bytes that the App stores and later submits.
    ///
    /// Sorted keys make repeated encoding deterministic. The source evidence
    /// must be written once; validators recalculate facts from these bytes but
    /// never rewrite them.
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

public enum PowerEvidenceTimestamp {
    public static func string(from date: Date) -> String {
        date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
                .time(includingFractionalSeconds: true)
                .timeZone(separator: .colon)
        )
    }
}
