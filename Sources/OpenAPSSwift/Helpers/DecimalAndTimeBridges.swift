import Foundation

// Bridge initializers that Trio's main app provides via
// Helpers/Decimal+Extensions.swift. Without these, several engine files
// fail to compile because Swift's stdlib `Double(_:)` / `Int(_:)` don't
// accept `Decimal`.
extension Double {
    init(_ decimal: Decimal) {
        self.init(truncating: decimal as NSNumber)
    }
}

extension Int {
    init(_ decimal: Decimal) {
        self.init(Double(decimal))
    }
}

// `Double.decimal` and `Decimal.rounded(toPlaces:)` are used by the engine
// (InsulinSensitivities decoder, DetermineBasalGenerator "tick" formatting,
// TDDStorage-style %.2f rounding). Trio defines them in scattered helper
// files; consolidated here so the algorithm subset compiles standalone.
extension Double {
    var decimal: Decimal? {
        guard isFinite else { return nil }
        return Decimal(self)
    }
}

extension Decimal {
    func rounded(toPlaces places: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, places, .plain)
        return result
    }

    func truncated(toPlaces places: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, places, .down)
        return result
    }
}

// `isNotEmpty` is provided in Trio via the `Occupiable` protocol
// (Helpers/ConvenienceExtensions.swift). We only need the Collection variant
// inside the engine subset.
extension Collection {
    var isNotEmpty: Bool { !isEmpty }
}

// Arithmetic mean over a Collection<Decimal>; Trio defines this in
// APS/Extensions/DecimalExtensions.swift.
extension Collection where Element == Decimal {
    var mean: Decimal {
        guard !isEmpty else { return .zero }
        return reduce(.zero, +) / Decimal(count)
    }
}

// TimeInterval convenience initializers used by the meal/iob pipelines.
// In Trio these live in a Snooze UI module (SnoozeRootView.swift); they're
// pure Foundation so we lift them here.
extension TimeInterval {
    init(minutes: Double) {
        self.init(minutes * 60)
    }

    init(hours: Double) {
        self.init(minutes: hours * 60)
    }

    static func minutes(_ minutes: Double) -> TimeInterval { TimeInterval(minutes: minutes) }
    static func hours(_ hours: Double) -> TimeInterval { TimeInterval(hours: hours) }

    var minutes: Double { self / 60.0 }
    var hours: Double { minutes / 60.0 }
}
