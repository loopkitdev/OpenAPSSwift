import Foundation

func decimalRound(_ value: Decimal, scale: Int, roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
    var result = Decimal()
    var toRound = value
    NSDecimalRound(&result, &toRound, scale, roundingMode)
    return result
}
