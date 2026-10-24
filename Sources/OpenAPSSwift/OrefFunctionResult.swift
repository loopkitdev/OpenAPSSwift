import Foundation

public enum OrefFunctionResult {
    case success(String)
    case failure(Error)

    public func returnOrThrow() throws -> String {
        switch self {
        case let .success(json): return json
        case let .failure(error): throw error
        }
    }
}
