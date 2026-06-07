import Foundation

/// End-to-end smoke runner for the extracted OpenAPSSwift pipeline.
///
/// Builds a synthetic 24h fixture (flat 120 mg/dL CGM, empty pump history,
/// no carbs) and runs each pipeline stage in order:
///
/// `makeProfile → meal → autosense → iob → determineBasal`
///
/// Each stage is asserted to return `.success`. Returns the final
/// `Determination` JSON as a String so external callers can inspect it.
///
/// This is the only `public` API on the extracted package today. When we
/// wire OpenAPSSwift into LoopEval's `DosingEngine` protocol the
/// individual stage methods will be promoted to `public` as well.
public enum Smoke {
    public struct Stage {
        public let name: String
        public let outputJSON: String
    }

    public static func runAll() throws -> [Stage] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let clock = ISO8601DateFormatter().date(from: "2026-06-01T12:00:00Z")!

        // 24h of synthetic CGM at 120 mg/dL, every 5 min, newest-first.
        let calendar = Calendar(identifier: .gregorian)
        var glucoseEntries: [String] = []
        for i in 0 ..< 289 {
            let date = calendar.date(byAdding: .minute, value: -5 * i, to: clock)!
            let dateString = iso.string(from: date)
            let unixMs = Int(date.timeIntervalSince1970 * 1000)
            glucoseEntries.append(
                #"{"_id":"g\#(i)","sgv":120,"glucose":120,"direction":"Flat","date":\#(unixMs),"dateString":"\#(dateString)","type":"sgv","noise":1}"#
            )
        }
        let glucoseJSON = "[" + glucoseEntries.joined(separator: ",") + "]"

        let pumpHistoryJSON = "[]"
        let carbsJSON = "[]"

        let basalProfileJSON = #"[{"start":"00:00:00","minutes":0,"rate":0.5}]"#
        let bgTargetsJSON = #"{"units":"mg/dL","user_preferred_units":"mg/dL","targets":[{"low":100,"high":100,"start":"00:00:00","offset":0}]}"#
        let isfJSON = #"{"units":"mg/dL","user_preferred_units":"mg/dL","sensitivities":[{"sensitivity":50,"offset":0,"start":"00:00:00"}]}"#
        let carbRatioJSON = #"{"units":"grams","schedule":[{"start":"00:00:00","offset":0,"ratio":10}]}"#
        let pumpSettingsJSON = #"{"insulin_action_curve":6,"maxBolus":10,"maxBasal":4}"#
        let preferencesJSON = "{}"
        let tempTargetsJSON = "[]"
        let trioSettingsJSON = "{}"
        let modelJSON = "\"X22\""

        let clockString = iso.string(from: clock)
        let trioCustomOrefJSON = """
        {"average_total_data":0,"currentTDD":0,"weightedAverage":1,\
        "past2hoursAverage":0,"date":"\(clockString)","overridePercentage":100,\
        "useOverride":false,"duration":0,"unlimited":false,"overrideTarget":0,\
        "smbIsOff":false,"advancedSettings":false,"isfAndCr":false,\
        "isf":false,"cr":false,"smbIsScheduledOff":false,"start":0,"end":0,\
        "smbMinutes":0,"uamMinutes":0}
        """

        let currentTempJSON = """
        {"duration":0,"rate":0,"temp":"absolute","timestamp":"\(clockString)"}
        """
        let reservoirJSON = "100"

        var stages: [Stage] = []

        // 1. makeProfile
        let profile = try OpenAPSSwift.makeProfile(
            preferences: preferencesJSON,
            pumpSettings: pumpSettingsJSON,
            bgTargets: bgTargetsJSON,
            basalProfile: basalProfileJSON,
            isf: isfJSON,
            carbRatio: carbRatioJSON,
            tempTargets: tempTargetsJSON,
            model: modelJSON,
            trioSettings: trioSettingsJSON,
            clock: clock
        ).returnOrThrow()
        stages.append(Stage(name: "makeProfile", outputJSON: profile))

        // 2. meal
        let meal = try OpenAPSSwift.meal(
            pumphistory: pumpHistoryJSON,
            profile: profile,
            basalProfile: basalProfileJSON,
            clock: clockString,
            carbs: carbsJSON,
            glucose: glucoseJSON
        ).returnOrThrow()
        stages.append(Stage(name: "meal", outputJSON: meal))

        // 3. autosense
        let autosens = try OpenAPSSwift.autosense(
            glucose: glucoseJSON,
            pumpHistory: pumpHistoryJSON,
            basalProfile: basalProfileJSON,
            profile: profile,
            carbs: carbsJSON,
            tempTargets: tempTargetsJSON,
            clock: clockString
        ).returnOrThrow()
        stages.append(Stage(name: "autosense", outputJSON: autosens))

        // 4. iob
        let iob = try OpenAPSSwift.iob(
            pumphistory: pumpHistoryJSON,
            profile: profile,
            clock: clockString,
            autosens: autosens
        ).returnOrThrow()
        stages.append(Stage(name: "iob", outputJSON: iob))

        // 5. determineBasal
        let determination = try OpenAPSSwift.determineBasal(
            glucose: glucoseJSON,
            currentTemp: currentTempJSON,
            iob: iob,
            profile: profile,
            autosens: autosens,
            meal: meal,
            microBolusAllowed: false,
            reservoir: reservoirJSON,
            pumpHistory: pumpHistoryJSON,
            preferences: preferencesJSON,
            basalProfile: basalProfileJSON,
            trioCustomOrefVariables: trioCustomOrefJSON,
            clock: clock
        ).returnOrThrow()
        stages.append(Stage(name: "determineBasal", outputJSON: determination))

        return stages
    }
}
