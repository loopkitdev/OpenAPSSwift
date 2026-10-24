import Foundation

/// Native inputs for `OpenAPSSwift.runPipeline`, built to equal what the JSON path decodes.
///
/// A host that used to send glucose, pump history and carbs as JSON strings spent most of each
/// oref step re-parsing the same 24 h of ISO-8601 dates. Building the models directly skips that,
/// but a date sent as a string comes back at the string's precision, and a `Double` sent as a JSON
/// number comes back as the `Decimal` of its printed digits, not of its binary value. These helpers
/// return exactly those values by running each distinct input through the real round trip once
/// (`JSONSerialization` out, `JSONCoding.decoder` in) and memoizing it. Consecutive oref steps share
/// almost all their dates and rates, so the round trips amortize away.
public enum OrefNative {
    private static let lock = NSLock()
    private static var dates: [Double: Date] = [:]
    private static var decimals: [UInt64: Decimal] = [:]

    /// The date oref decodes from `formatted(d)` sent as a JSON string.
    public static func date(_ d: Date, formatted: (Date) -> String) -> Date {
        let key = d.timeIntervalSinceReferenceDate
        lock.lock()
        if let hit = dates[key] { lock.unlock(); return hit }
        lock.unlock()
        let json = Data("[\"\(formatted(d))\"]".utf8)
        let value = (try? JSONCoding.decoder.decode([Date].self, from: json))?.first ?? d
        lock.lock(); dates[key] = value; lock.unlock()
        return value
    }

    /// The `Decimal` oref decodes from `x` written by `JSONSerialization`.
    public static func decimal(_ x: Double) -> Decimal {
        let key = x.bitPattern
        lock.lock()
        if let hit = decimals[key] { lock.unlock(); return hit }
        lock.unlock()
        let value: Decimal
        if let data = try? JSONSerialization.data(withJSONObject: [x]),
           let decoded = try? JSONCoding.decoder.decode([Decimal].self, from: data).first
        {
            value = decoded
        } else {
            value = Decimal(x)
        }
        lock.lock(); decimals[key] = value; lock.unlock()
        return value
    }
}
