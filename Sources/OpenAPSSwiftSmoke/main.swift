import Foundation
import OpenAPSSwift

do {
    let stages = try Smoke.runAll()
    for stage in stages {
        print("=== \(stage.name) ===")
        print(stage.outputJSON)
        print()
    }
    print("Smoke test passed. \(stages.count) stages.")
} catch {
    print("Smoke test FAILED: \(error)")
    exit(1)
}
