import Foundation

struct RaceResult: Identifiable {
    let id = UUID()
    let label: String
    let expected: Int
    let actual: Int
    var passed: Bool { expected == actual }
}
