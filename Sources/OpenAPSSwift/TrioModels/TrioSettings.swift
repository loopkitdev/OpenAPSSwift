import Foundation

// Minimal stub for the OpenAPSSwift extraction. The full TrioSettings in the
// original Trio app carries UI/display preferences (Garmin watchface choices,
// lockscreen view, etc.) that the algorithm pipeline does not read. We keep
// an empty Codable so JSONBridge.trioSettings(from:) still decodes any
// payload, but no fields are surfaced to the engine.
struct TrioSettings: JSON, Equatable {
    init() {}
}

extension TrioSettings: Codable {
    init(from _: Decoder) throws {}
    func encode(to _: Encoder) throws {}
}
