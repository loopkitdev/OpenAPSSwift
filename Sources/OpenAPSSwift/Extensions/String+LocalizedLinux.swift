import Foundation

#if os(Linux)
    // swift-corelibs Foundation has no `String(localized:)` for these literals; on Linux the messages
    // stay in English. Darwin builds are unaffected and keep their localization.
    extension String {
        init(localized value: String) {
            self = value
        }
    }
#endif
