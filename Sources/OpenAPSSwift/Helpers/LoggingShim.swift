import Foundation

// Minimal stand-in for Trio's logger helpers. The main app uses a category-
// aware logger; here we only need the call signatures to resolve. Output goes
// to stdout when the OPENAPSSWIFT_LOG env var is set; otherwise silent.

enum LogCategory {
    case openAPS
    case service
    case nightscout
    case dynamicVariables
    case statistics
}

@inline(__always)
private func shouldLog() -> Bool {
    ProcessInfo.processInfo.environment["OPENAPSSWIFT_LOG"] != nil
}

func debug(_ category: LogCategory, _ message: @autoclosure () -> String) {
    if shouldLog() { print("[debug:\(category)] \(message())") }
}

func warning(_ category: LogCategory, _ message: @autoclosure () -> String, error: Error? = nil) {
    if shouldLog() {
        if let error { print("[warn:\(category)] \(message()) — \(error)") }
        else        { print("[warn:\(category)] \(message())") }
    }
}

func error(_ category: LogCategory, _ message: @autoclosure () -> String, error: Error? = nil) {
    if shouldLog() {
        if let e = error { print("[error:\(category)] \(message()) — \(e)") }
        else             { print("[error:\(category)] \(message())") }
    }
}
