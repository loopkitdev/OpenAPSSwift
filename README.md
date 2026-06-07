# OpenAPSSwift

A standalone Swift Package extraction of the oref0 algorithm port from
[nightscout/Trio](https://github.com/nightscout/Trio), branch
`feat/dev-oref-swift`. Carved out so a host project can call oref's
`determineBasal` (and friends) without depending on the full Trio
application.

This is the source used by [loopkitdev/LoopEval](https://github.com/loopkitdev/LoopEval)
as a second `DosingEngine` for closed-loop counterfactual evaluation.

## What's in the box

```
Sources/OpenAPSSwift/        — the library
  OpenAPSSwift.swift         — public façade: makeProfile, meal,
                                autosense, iob, determineBasal
  JSONBridge.swift           — JSON-in/JSON-out boundary
  OrefFunctionResult.swift   — typed result wrapper
  Helpers/                   — JSON, rounding, formatters, Decimal/Date
                                bridges, logging shim
  Engine subdirs             — Autosens, DetermineBasal, Forecasts,
                                Iob, Meal, Models, Profile, Utils,
                                TrioModels
Sources/OpenAPSSwiftSmoke/   — executable smoke target (sanity-check
                                that the package builds and the public
                                API is reachable)
```

74 Swift source files. All public entry points are `JSON-in / JSON-out`
so the package can be linked against any host without dragging in
Trio's app-level types.

## Usage

```swift
import OpenAPSSwift

let determinationJSON = try OpenAPSSwift.determineBasal(
    iobInputs:    iobJSON,
    meal:         mealJSON,
    profile:      profileJSON,
    glucose:      glucoseJSON,
    currentTemp:  tempJSON,
    autosens:     autosensJSON,
    pumpHistory:  pumpHistoryJSON,
    preferences:  prefsJSON
)
```

See `Sources/OpenAPSSwiftSmoke/main.swift` for a worked example, and
the `OpenAPSAdapter` in LoopEval (`Sources/EvalCore/Engine/OpenAPSAdapter.swift`)
for a full host integration that translates simulator state into the
JSON shapes above and back.

## Building

```sh
swift build
swift build -c release
swift run OpenAPSSwiftSmoke   # builds + runs the smoke executable
```

Requires Swift 6.0 toolchain (declared in `Package.swift`). Tested on
macOS 13+ and iOS 15+.

## Licensing

**AGPL-3.0** (see `LICENSE`). Trio is licensed AGPL-3.0; because this
extraction is a derived work, the same license applies. If you link
this into a network-served application, the AGPL-3.0 obligations apply
to your service.

## Provenance

Extracted in June 2026 from `nightscout/Trio` commit on the
`feat/dev-oref-swift` branch. Original source paths were
`Trio/Sources/APS/OpenAPSSwift/` plus the model + helper files it
transitively referenced from `Trio/Sources/{Models,Helpers}/`.

No algorithm changes from the upstream Trio extraction — this package
is a *packaging change only*. Bug fixes and behavior changes that show
up here should be considered for upstreaming to Trio.

## Related projects

- [nightscout/Trio](https://github.com/nightscout/Trio) — the source
  project, full app + algorithm.
- [openaps/oref0](https://github.com/openaps/oref0) — the original
  JavaScript algorithm that Trio's Swift port mirrors.
- [loopkitdev/LoopEval](https://github.com/loopkitdev/LoopEval) — the
  primary host for this package; provides Loop-vs-OAPS closed-loop
  counterfactual evaluation.
