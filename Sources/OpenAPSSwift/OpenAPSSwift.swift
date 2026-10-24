import Foundation

/// JSON-in / JSON-out façade over Trio's oref generators, for hosts that are not the Trio app.
///
/// Trio 1.0 calls the generators with native models from `Trio/Sources/APS/OpenAPS/OpenAPS.swift`
/// and does some algorithm-relevant work there, outside the generators. The façade reproduces
/// that work so a determination here is the one Trio would make on the same inputs:
///
/// - profile: an active temp target's effective half-basal target replaces
///   `halfBasalExerciseTarget` (`TempTargetCalculations.computeEffectiveHBT`), and
///   `lowTemptargetLowersSensitivity` is cleared when `autosensMax <= 1` (`createProfiles`);
/// - profile: the pump's supported basal rates are injected (`profile.supportedBasalRates`);
/// - IOB: duplicate suspend/resume events are removed first (`iob(pumphistory:…)`);
/// - autosens: the lower of the 8 h and 24 h ratios (`autosense(glucose:…)`);
/// - determination: dynamic ISF is switched off when Trio would lack the TDD history for it
///   (`hasSufficientTdd`, ≥75% of 7 days of 5-minute TDD records).
///
/// Dosing mode is closed loop (`Preferences.clamped(for: .closed)` is the identity).
public struct OpenAPSSwift {
    public static func makeProfile(
        preferences: String,
        pumpSettings: String,
        bgTargets: String,
        basalProfile: String,
        isf: String,
        carbRatio: String,
        tempTargets: String,
        model: String,
        trioSettings: String,
        clock: Date,
        supportedBasalRates: [Decimal] = []
    ) -> OrefFunctionResult {
        _ = (model, trioSettings) // accepted for signature parity; Trio 1.0's ProfileGenerator takes neither
        do {
            let profile = try generateProfile(
                preferences: FacadeJSON.preferences(from: preferences),
                pumpSettings: JSONBridge.pumpSettings(from: pumpSettings),
                bgTargets: JSONBridge.bgTargets(from: bgTargets),
                basalProfile: JSONBridge.basalProfile(from: basalProfile),
                isf: JSONBridge.insulinSensitivities(from: isf),
                carbRatios: JSONBridge.carbRatios(from: carbRatio),
                tempTargets: JSONBridge.tempTargets(from: tempTargets),
                clock: clock,
                supportedBasalRates: supportedBasalRates
            )
            return try .success(FacadeJSON.to(profile))
        } catch {
            return .failure(error)
        }
    }

    public static func determineBasal(
        glucose: String,
        currentTemp: String,
        iob: String,
        profile: String,
        autosens: String,
        meal: String,
        microBolusAllowed: Bool,
        reservoir: String,
        pumpHistory: String,
        preferences: String,
        basalProfile: String,
        trioCustomOrefVariables: String,
        clock: Date,
        hasSufficientTdd: Bool = true
    ) -> OrefFunctionResult {
        _ = (pumpHistory, basalProfile) // Trio 1.0's DeterminationGenerator takes neither
        do {
            let glucose = try FacadeJSON.glucose(from: glucose)
            let currentTemp = try FacadeJSON.currentTemp(from: currentTemp)
            let iob = try FacadeJSON.iobResult(from: iob)
            let profile = try JSONBridge.profile(from: profile)
            guard let autosens = try JSONBridge.autosens(from: autosens),
                  let meal = try FacadeJSON.computedCarbs(from: meal)
            else { throw DeterminationError.missingInputs }
            let reservoir = Decimal(string: reservoir) ?? 100
            let preferences = try FacadeJSON.preferences(from: preferences)
            let trioCustom = try JSONBridge.trioCustomOrefVariables(from: trioCustomOrefVariables)
            return try determine(
                glucose: glucose, currentTemp: currentTemp, iob: iob, profile: profile, autosens: autosens,
                meal: meal, microBolusAllowed: microBolusAllowed, reservoir: reservoir, preferences: preferences,
                trioCustom: trioCustom, clock: clock, hasSufficientTdd: hasSufficientTdd
            )
        } catch {
            return .failure(error)
        }
    }

    public static func meal(
        pumphistory: String,
        profile: String,
        basalProfile: String,
        clock: String,
        carbs: String,
        glucose: String
    ) -> OrefFunctionResult {
        do {
            let mealResult = try MealGenerator.generate(
                pumpHistory: FacadeJSON.pumpHistory(from: pumphistory),
                profile: JSONBridge.profile(from: profile),
                basalProfile: JSONBridge.basalProfile(from: basalProfile),
                clock: FacadeJSON.clock(from: clock),
                carbHistory: FacadeJSON.carbs(from: carbs),
                glucoseHistory: FacadeJSON.glucose(from: glucose)
            )
            return try .success(FacadeJSON.to(mealResult))
        } catch {
            return .failure(error)
        }
    }

    public static func iob(pumphistory: String, profile: String, clock: String, autosens: String) -> OrefFunctionResult {
        do {
            let iobResult = try IobGenerator.generate(
                history: FacadeJSON.pumpHistory(from: pumphistory).removingDuplicateSuspendResumeEvents(),
                profile: JSONBridge.profile(from: profile),
                clock: FacadeJSON.clock(from: clock),
                autosens: JSONBridge.autosens(from: autosens)
            )
            return try .success(FacadeJSON.to(iobResult))
        } catch {
            return .failure(error)
        }
    }

    public static func autosense(
        glucose: String,
        pumpHistory: String,
        basalProfile: String,
        profile: String,
        carbs: String,
        tempTargets: String,
        clock: String
    ) -> OrefFunctionResult {
        do {
            let autosens = try autosense(
                glucose: FacadeJSON.glucose(from: glucose),
                pumpHistory: FacadeJSON.pumpHistory(from: pumpHistory),
                basalProfile: JSONBridge.basalProfile(from: basalProfile),
                profile: JSONBridge.profile(from: profile),
                carbs: FacadeJSON.carbs(from: carbs),
                tempTargets: JSONBridge.tempTargets(from: tempTargets),
                clock: FacadeJSON.clock(from: clock)
            )
            return try .success(FacadeJSON.to(autosens))
        } catch {
            return .failure(error)
        }
    }

    /// Combined pipeline: profile → meal → autosens → iob → determineBasal, parsing each raw input
    /// once and passing the parsed models between generators. Same generators, same order and same
    /// app-layer steps as the separate calls. Returns the determination JSON (or the {"error":…}
    /// JSON, matching determineBasal) plus the autosens ratio. Throws on any non-determination error.
    public static func runPipeline(
        preferences: String,
        pumpSettings: String,
        bgTargets: String,
        basalProfile: String,
        isf: String,
        carbRatio: String,
        model: String,
        trioSettings: String,
        pumpHistory: String,
        carbs: String,
        glucose: String,
        currentTemp: String,
        reservoir: String,
        microBolusAllowed: Bool,
        trioCustomOrefVariables: String,
        clockDate: Date,
        clockJSON: String,
        tempTargets: String = "[]",
        supportedBasalRates: [Decimal] = [],
        hasSufficientTdd: Bool = true
    ) throws -> (determination: String, autosensRatio: Double) {
        _ = (model, trioSettings)
        // Match the separate-call clock usage: makeProfile/determineBasal take the Date,
        // meal/autosens/iob the parsed clock string.
        let clockParsed = try FacadeJSON.clock(from: clockJSON)
        let prefs = try FacadeJSON.preferences(from: preferences)
        let basal = try JSONBridge.basalProfile(from: basalProfile)
        let tt = try JSONBridge.tempTargets(from: tempTargets)
        let ph = try FacadeJSON.pumpHistory(from: pumpHistory)
        let carbsArr = try FacadeJSON.carbs(from: carbs)
        let glu = try FacadeJSON.glucose(from: glucose)
        let curTemp = try FacadeJSON.currentTemp(from: currentTemp)
        let resv = Decimal(string: reservoir) ?? 100
        let trioCustom = try JSONBridge.trioCustomOrefVariables(from: trioCustomOrefVariables)

        let profile = try generateProfile(
            preferences: prefs,
            pumpSettings: JSONBridge.pumpSettings(from: pumpSettings),
            bgTargets: JSONBridge.bgTargets(from: bgTargets),
            basalProfile: basal,
            isf: JSONBridge.insulinSensitivities(from: isf),
            carbRatios: JSONBridge.carbRatios(from: carbRatio),
            tempTargets: tt,
            clock: clockDate,
            supportedBasalRates: supportedBasalRates
        )

        let meal = try MealGenerator.generate(
            pumpHistory: ph, profile: profile, basalProfile: basal,
            clock: clockParsed, carbHistory: carbsArr, glucoseHistory: glu
        )
        let autosens = try autosense(
            glucose: glu, pumpHistory: ph, basalProfile: basal, profile: profile,
            carbs: carbsArr, tempTargets: tt, clock: clockParsed
        )
        let ratio = NSDecimalNumber(decimal: autosens.ratio).doubleValue
        let iob = try IobGenerator.generate(
            history: ph.removingDuplicateSuspendResumeEvents(), profile: profile, clock: clockParsed, autosens: autosens
        )
        guard let mealData = meal else { throw DeterminationError.missingInputs }

        let det = try determine(
            glucose: glu, currentTemp: curTemp, iob: iob, profile: profile, autosens: autosens, meal: mealData,
            microBolusAllowed: microBolusAllowed, reservoir: resv, preferences: prefs, trioCustom: trioCustom,
            clock: clockDate, hasSufficientTdd: hasSufficientTdd
        )
        // Golden-master dump: the determine-basal inputs (oref0 JSON shape) at one target cycle, so
        // Trio's own code can be run on identical inputs and compared. Env-gated.
        if let gm = ProcessInfo.processInfo.environment["OREF_GM_TIME"],
           let target = ISO8601DateFormatter().date(from: gm),
           abs(clockDate.timeIntervalSince(target)) < 150
        {
            let dir = "/tmp/gm"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            func d(_ s: String, _ n: String) { try? s.write(toFile: "\(dir)/\(n).json", atomically: true, encoding: .utf8) }
            d(try FacadeJSON.to(profile), "profile")
            d(try FacadeJSON.to(iob), "iob")
            d(try FacadeJSON.to(mealData), "meal")
            d(try FacadeJSON.to(autosens), "autosens")
            d(try FacadeJSON.to(glu), "glucose")
            d(try FacadeJSON.to(curTemp), "currenttemp")
            d(preferences, "preferences")
            d(basalProfile, "basalprofile")
            d(try FacadeJSON.to(trioCustom), "trio_custom")
            if case let .success(s) = det { d(s, "our_determination") }
            d("\"\(ISO8601DateFormatter().string(from: clockDate))\"", "clock")
            d(pumpHistory, "raw_pumphistory")
            d(carbs, "raw_carbs")
            d(pumpSettings, "raw_pumpsettings")
            d(bgTargets, "raw_bgtargets")
            d(isf, "raw_isf")
            d(carbRatio, "raw_carbratio")
            d(tempTargets, "raw_temptargets")
            FileHandle.standardError.write(Data("GM dumped at \(clockDate)\n".utf8))
        }
        return (try det.returnOrThrow(), ratio)
    }

    // MARK: - Trio 1.0 app-layer steps

    /// `OpenAPS.createProfiles`: temp-target half-basal adjustment and the low-TT guard, then
    /// `ProfileGenerator`; the pump's rate table is injected as in `OpenAPS.determineBasal`.
    static func generateProfile(
        preferences: Preferences,
        pumpSettings: PumpSettings,
        bgTargets: BGTargets,
        basalProfile: [BasalProfileEntry],
        isf: InsulinSensitivities,
        carbRatios: CarbRatios,
        tempTargets: [TempTarget],
        clock: Date,
        supportedBasalRates: [Decimal]
    ) throws -> Profile {
        var adjusted = preferences
        if let active = activeTempTarget(tempTargets, at: clock),
           active.enabled ?? true,
           let target = active.targetBottom ?? active.targetTop,
           let hbt = TempTargetCalculations.computeEffectiveHBT(
               tempTargetHalfBasalTarget: active.halfBasalTarget,
               settingHalfBasalTarget: preferences.halfBasalExerciseTarget,
               target: target,
               autosensMax: preferences.autosensMax
           ),
           hbt != preferences.halfBasalExerciseTarget
        {
            adjusted.halfBasalExerciseTarget = hbt
        }
        if preferences.lowTemptargetLowersSensitivity, preferences.autosensMax <= 1 {
            adjusted.lowTemptargetLowersSensitivity = false
        }
        var profile = try ProfileGenerator.generate(
            pumpSettings: pumpSettings,
            bgTargets: bgTargets,
            basalProfile: basalProfile,
            isf: isf,
            preferences: adjusted,
            carbRatios: carbRatios,
            tempTargets: tempTargets,
            clock: clock
        )
        profile.supportedBasalRates = supportedBasalRates
        return profile
    }

    /// The temp target in effect at `clock`: the latest one started at or before it whose duration
    /// covers it (a zero-duration target cancels).
    static func activeTempTarget(_ tempTargets: [TempTarget], at clock: Date) -> TempTarget? {
        guard let latest = tempTargets.filter({ $0.createdAt <= clock }).max(by: { $0.createdAt < $1.createdAt }),
              latest.duration > 0,
              clock < latest.createdAt.addingTimeInterval(TimeInterval(truncating: latest.duration as NSNumber) * 60)
        else { return nil }
        return latest
    }

    /// `OpenAPS.autosense(glucose:…)`: 8 h and 24 h ratios over shared treatments, keep the lower.
    static func autosense(
        glucose: [BloodGlucose],
        pumpHistory: [PumpHistoryEvent],
        basalProfile: [BasalProfileEntry],
        profile: Profile,
        carbs: [CarbsEntry],
        tempTargets: [TempTarget],
        clock: Date
    ) throws -> Autosens {
        let precomputed = glucose.count >= 72 ? try IobHistory.calcTempTreatments(
            history: pumpHistory.map { $0.computedEvent() },
            profile: profile,
            clock: clock,
            autosens: nil,
            zeroTempDuration: nil
        ) : nil
        let ratio8h = try AutosensGenerator.generate(
            glucose: glucose, pumpHistory: pumpHistory, basalProfile: basalProfile, profile: profile,
            carbs: carbs, tempTargets: tempTargets, maxDeviations: 96, clock: clock,
            precomputedTreatments: precomputed
        )
        let ratio24h = try AutosensGenerator.generate(
            glucose: glucose, pumpHistory: pumpHistory, basalProfile: basalProfile, profile: profile,
            carbs: carbs, tempTargets: tempTargets, maxDeviations: 288, clock: clock,
            precomputedTreatments: precomputed
        )
        return ratio8h.ratio < ratio24h.ratio ? ratio8h : ratio24h
    }

    /// `OpenAPS.determineBasal`: the insufficient-TDD guard on dynamic ISF, then the generator.
    static func determine(
        glucose: [BloodGlucose],
        currentTemp: TempBasal,
        iob: [IobResult],
        profile: Profile,
        autosens: Autosens,
        meal: ComputedCarbs,
        microBolusAllowed: Bool,
        reservoir: Decimal,
        preferences: Preferences,
        trioCustom: TrioCustomOrefVariables,
        clock: Date,
        hasSufficientTdd: Bool
    ) throws -> OrefFunctionResult {
        var preferences = preferences
        if !hasSufficientTdd, preferences.useNewFormula {
            preferences.useNewFormula = false
            preferences.sigmoid = false
        }
        do {
            let det = try DeterminationGenerator.generate(
                profile: profile, preferences: preferences, currentTemp: currentTemp,
                iobData: iob, mealData: meal, autosensData: autosens,
                reservoirData: reservoir, glucose: glucose, microBolusAllowed: microBolusAllowed,
                trioCustomOrefVariables: trioCustom, currentTime: clock
            )
            return try .success(FacadeJSON.to(det))
        } catch let determinationError as DeterminationError {
            return try .success(FacadeJSON.to(DeterminationErrorResponse(error: determinationError.localizedDescription)))
        }
    }
}

struct DeterminationErrorResponse: Codable {
    let error: String
}

/// Decoders Trio 1.0 dropped from `JSONBridge` when its app went native, kept for the façade.
enum FacadeJSON {
    static func preferences(from s: String) throws -> Preferences { try JSONBridge.from(string: s) }
    static func glucose(from s: String) throws -> [BloodGlucose] { try JSONBridge.from(string: s) }
    static func currentTemp(from s: String) throws -> TempBasal { try JSONBridge.from(string: s) }
    static func carbs(from s: String) throws -> [CarbsEntry] { try JSONBridge.from(string: s) }
    static func iobResult(from s: String) throws -> [IobResult] { try JSONBridge.from(string: s) }
    static func computedCarbs(from s: String) throws -> ComputedCarbs? { try JSONBridge.from(string: s) }

    /// An empty object "{}" is an empty history.
    static func pumpHistory(from s: String) throws -> [PumpHistoryEvent] {
        do {
            return try JSONBridge.from(string: s)
        } catch {
            if let data = s.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], obj.isEmpty
            {
                return []
            }
            throw error
        }
    }

    static func clock(from s: String) throws -> Date {
        let str = s.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = Formatter.iso8601withFractionalSeconds.date(from: str) ?? Formatter.iso8601.date(from: str) {
            return date
        }
        throw JSONError.invalidDate(s)
    }

    static func to<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONCoding.encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else { throw JSONError.encodingFailed }
        return string
    }
}
