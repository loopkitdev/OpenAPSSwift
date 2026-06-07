import Foundation

public enum OrefFunctionResult {
    case success(RawJSON)
    case failure(Error)

    public func returnOrThrow() throws -> RawJSON {
        switch self {
        case let .success(json): return json
        case let .failure(error): throw error
        }
    }
}
