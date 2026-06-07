import Foundation

// ISO-8601 formatters and custom date strategies used by JSONBridge.clock,
// the engine's JSON coding helpers, and various model decoders. Lifted from
// Trio/Sources/Helpers/Formatters.swift.
//
// `nonisolated(unsafe)` is required under Swift 6 because ISO8601DateFormatter
// is not Sendable. In practice these instances are configured once at static
// init and only read (`.date(from:)` / `.string(from:)`); ISO8601DateFormatter
// is documented as thread-safe for that usage.
extension Formatter {
    nonisolated(unsafe) static let iso8601withFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

extension JSONDecoder.DateDecodingStrategy {
    static let customISO8601 = custom {
        let container = try $0.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = Formatter.iso8601withFractionalSeconds.date(from: string)
            ?? Formatter.iso8601.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
    }
}

extension JSONEncoder.DateEncodingStrategy {
    static let customISO8601 = custom {
        var container = $1.singleValueContainer()
        try container.encode(Formatter.iso8601withFractionalSeconds.string(from: $0))
    }
}
