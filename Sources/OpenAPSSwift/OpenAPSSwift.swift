import Foundation

public struct OpenAPSSwift {
    public static func makeProfile(
        preferences: JSON,
        pumpSettings: JSON,
        bgTargets: JSON,
        basalProfile: JSON,
        isf: JSON,
        carbRatio: JSON,
        tempTargets: JSON,
        model: JSON,
        trioSettings: JSON,
        clock: Date
    ) -> (OrefFunctionResult) {
        do {
            let preferences = try JSONBridge.preferences(from: preferences)
            let pumpSettings = try JSONBridge.pumpSettings(from: pumpSettings)
            let bgTargets = try JSONBridge.bgTargets(from: bgTargets)
            let basalProfile = try JSONBridge.basalProfile(from: basalProfile)
            let isf = try JSONBridge.insulinSensitivities(from: isf)
            let carbRatio = try JSONBridge.carbRatios(from: carbRatio)
            let tempTargets = try JSONBridge.tempTargets(from: tempTargets)
            let model = JSONBridge.model(from: model)
            let trioSettings = try JSONBridge.trioSettings(from: trioSettings)

            let profile = try ProfileGenerator.generate(
                pumpSettings: pumpSettings,
                bgTargets: bgTargets,
                basalProfile: basalProfile,
                isf: isf,
                preferences: preferences,
                carbRatios: carbRatio,
                tempTargets: tempTargets,
                model: model,
                clock: clock
            )

            return (try .success(JSONBridge.to(profile)))
        } catch {
            return (.failure(error))
        }
    }

    public static func determineBasal(
        glucose: JSON,
        currentTemp: JSON,
        iob: JSON,
        profile: JSON,
        autosens: JSON,
        meal: JSON,
        microBolusAllowed: Bool,
        reservoir: JSON,
        pumpHistory: JSON,
        preferences: JSON,
        basalProfile: JSON,
        trioCustomOrefVariables: JSON,
        clock: Date
    ) -> (OrefFunctionResult) {
        do {
            let glucose = try JSONBridge.glucose(from: glucose)
            let currentTemp = try JSONBridge.currentTemp(from: currentTemp)
            let iob = try JSONBridge.iobResult(from: iob)
            let profile = try JSONBridge.profile(from: profile)
            let autosens = try JSONBridge.autosens(from: autosens)
            let meal = try JSONBridge.computedCarbs(from: meal)
            let microBolusAllowed = microBolusAllowed
            let reservoir = Decimal(string: reservoir.rawJSON)
            let pumpHistory = try JSONBridge.pumpHistory(from: pumpHistory)
            let preferences = try JSONBridge.preferences(from: preferences)
            let basalProfile = try JSONBridge.basalProfile(from: basalProfile)
            let trioCustomOrefVariables = try JSONBridge.trioCustomOrefVariables(from: trioCustomOrefVariables)

            guard let mealData = meal, let autosensData = autosens else {
                return .failure(DeterminationError.missingInputs)
            }

            let rawDetermination = try DeterminationGenerator.generate(
                profile: profile,
                preferences: preferences,
                currentTemp: currentTemp,
                iobData: iob,
                mealData: mealData,
                autosensData: autosensData,
                reservoirData: reservoir ?? 100,
                glucose: glucose,
                microBolusAllowed: microBolusAllowed,
                trioCustomOrefVariables: trioCustomOrefVariables,
                currentTime: clock
            )

            return try .success(JSONBridge.to(rawDetermination))

        } catch let determinationError as DeterminationError {
            // if we get a determination error we want to return it as a JSON
            // object that is { "error": "some error" }
            do {
                let response = try JSONBridge.to(DeterminationErrorResponse(error: determinationError.localizedDescription))
                return .success(response)
            } catch {
                return .failure(determinationError)
            }
        } catch {
            return .failure(error)
        }
    }

    public static func meal(
        pumphistory: JSON,
        profile: JSON,
        basalProfile: JSON,
        clock: JSON,
        carbs: JSON,
        glucose: JSON
    ) -> (OrefFunctionResult) {
        do {
            let pumpHistory = try JSONBridge.pumpHistory(from: pumphistory)
            let profile = try JSONBridge.profile(from: profile)
            let basalProfile = try JSONBridge.basalProfile(from: basalProfile)
            let clock = try JSONBridge.clock(from: clock)
            let carbs = try JSONBridge.carbs(from: carbs)
            let glucose = try JSONBridge.glucose(from: glucose)

            let mealResult = try MealGenerator.generate(
                pumpHistory: pumpHistory,
                profile: profile,
                basalProfile: basalProfile,
                clock: clock,
                carbHistory: carbs,
                glucoseHistory: glucose
            )

            return try .success(JSONBridge.to(mealResult))
        } catch {
            return .failure(error)
        }
    }

    public static func iob(pumphistory: JSON, profile: JSON, clock: JSON, autosens: JSON) -> (OrefFunctionResult) {
        do {
            let pumpHistory = try JSONBridge.pumpHistory(from: pumphistory)
            let profile = try JSONBridge.profile(from: profile)
            let clock = try JSONBridge.clock(from: clock)
            let autosens = try JSONBridge.autosens(from: autosens)

            let iobResult = try IobGenerator.generate(
                history: pumpHistory,
                profile: profile,
                clock: clock,
                autosens: autosens
            )

            return try .success(JSONBridge.to(iobResult))
        } catch {
            return .failure(error)
        }
    }

    public static func autosense(
        glucose: JSON,
        pumpHistory: JSON,
        basalProfile: JSON,
        profile: JSON,
        carbs: JSON,
        tempTargets: JSON,
        clock: JSON,
        includeDeviationsForTesting: Bool = false
    ) -> (OrefFunctionResult) {
        do {
            let glucose = try JSONBridge.glucose(from: glucose)
            let pumpHistory = try JSONBridge.pumpHistory(from: pumpHistory)
            let basalProfile = try JSONBridge.basalProfile(from: basalProfile)
            let profile = try JSONBridge.profile(from: profile)
            let carbs = try JSONBridge.carbs(from: carbs)
            let tempTargets = try JSONBridge.tempTargets(from: tempTargets)
            let clock = try JSONBridge.clock(from: clock)

            // this logic is from prepare/autosens.js
            let ratio8h = try AutosensGenerator.generate(
                glucose: glucose,
                pumpHistory: pumpHistory,
                basalProfile: basalProfile,
                profile: profile,
                carbs: carbs,
                tempTargets: tempTargets,
                maxDeviations: 96,
                clock: clock,
                includeDeviationsForTesting: includeDeviationsForTesting
            )

            let ratio24h = try AutosensGenerator.generate(
                glucose: glucose,
                pumpHistory: pumpHistory,
                basalProfile: basalProfile,
                profile: profile,
                carbs: carbs,
                tempTargets: tempTargets,
                maxDeviations: 288,
                clock: clock,
                includeDeviationsForTesting: includeDeviationsForTesting
            )

            let lowestRatio = ratio8h.ratio < ratio24h.ratio ? ratio8h : ratio24h

            return try .success(JSONBridge.to(lowestRatio))
        } catch {
            return .failure(error)
        }
    }

    /// Combined pipeline: profile → meal → autosens → iob → determineBasal, parsing
    /// each raw input ONCE and passing the SAME parsed structs between generators
    /// (no intermediate JSON serialize/reparse). Mathematically identical to calling
    /// makeProfile/meal/autosense/iob/determineBasal in sequence — same generators,
    /// same order — but avoids re-parsing profile/pumpHistory/glucose 3–4× per step.
    /// Returns the determination JSON (or the {"error":…} JSON, matching determineBasal)
    /// plus the autosens ratio (for diagnostics). Throws on any non-determination error,
    /// matching the per-call `.returnOrThrow()` behavior of the separate functions.
    public static func runPipeline(
        preferences: JSON,
        pumpSettings: JSON,
        bgTargets: JSON,
        basalProfile: JSON,
        isf: JSON,
        carbRatio: JSON,
        model: JSON,
        trioSettings: JSON,
        pumpHistory: JSON,
        carbs: JSON,
        glucose: JSON,
        currentTemp: JSON,
        reservoir: JSON,
        microBolusAllowed: Bool,
        trioCustomOrefVariables: JSON,
        clockDate: Date,
        clockJSON: JSON
    ) throws -> (determination: String, autosensRatio: Double) {
        // Match the separate-call clock usage exactly: makeProfile/determineBasal
        // used the Date (req.t); meal/autosens/iob used the parsed clock-string.
        let clockParsed = try JSONBridge.clock(from: clockJSON)
        // ── parse every raw input exactly once ──
        let prefs       = try JSONBridge.preferences(from: preferences)
        let pumpSet     = try JSONBridge.pumpSettings(from: pumpSettings)
        let tgts        = try JSONBridge.bgTargets(from: bgTargets)
        let basal       = try JSONBridge.basalProfile(from: basalProfile)
        let isfP        = try JSONBridge.insulinSensitivities(from: isf)
        let cr          = try JSONBridge.carbRatios(from: carbRatio)
        let tt: [TempTarget] = []
        let mdl         = JSONBridge.model(from: model)
        let ph          = try JSONBridge.pumpHistory(from: pumpHistory)
        let carbsArr    = try JSONBridge.carbs(from: carbs)
        let glu         = try JSONBridge.glucose(from: glucose)
        let curTemp     = try JSONBridge.currentTemp(from: currentTemp)
        let resv        = Decimal(string: reservoir.rawJSON) ?? 100
        let trioCustom  = try JSONBridge.trioCustomOrefVariables(from: trioCustomOrefVariables)
        _ = trioSettings  // accepted for signature parity with makeProfile; ProfileGenerator ignores it

        let profile = try ProfileGenerator.generate(
            pumpSettings: pumpSet, bgTargets: tgts, basalProfile: basal, isf: isfP,
            preferences: prefs, carbRatios: cr, tempTargets: tt, model: mdl, clock: clockDate)

        let meal = try MealGenerator.generate(
            pumpHistory: ph, profile: profile, basalProfile: basal,
            clock: clockParsed, carbHistory: carbsArr, glucoseHistory: glu)

        let r8 = try AutosensGenerator.generate(
            glucose: glu, pumpHistory: ph, basalProfile: basal, profile: profile,
            carbs: carbsArr, tempTargets: tt, maxDeviations: 96, clock: clockParsed)
        let r24 = try AutosensGenerator.generate(
            glucose: glu, pumpHistory: ph, basalProfile: basal, profile: profile,
            carbs: carbsArr, tempTargets: tt, maxDeviations: 288, clock: clockParsed)
        let autosens = r8.ratio < r24.ratio ? r8 : r24
        let ratio = NSDecimalNumber(decimal: autosens.ratio).doubleValue

        let iob = try IobGenerator.generate(
            history: ph, profile: profile, clock: clockParsed, autosens: autosens)

        guard let mealData = meal else { throw DeterminationError.missingInputs }

        do {
            let rawDet = try DeterminationGenerator.generate(
                profile: profile, preferences: prefs, currentTemp: curTemp,
                iobData: iob, mealData: mealData, autosensData: autosens,
                reservoirData: resv, glucose: glu, microBolusAllowed: microBolusAllowed,
                trioCustomOrefVariables: trioCustom, currentTime: clockDate)
            return (try JSONBridge.to(rawDet), ratio)
        } catch let determinationError as DeterminationError {
            let response = try JSONBridge.to(DeterminationErrorResponse(error: determinationError.localizedDescription))
            return (response, ratio)
        }
    }
}
