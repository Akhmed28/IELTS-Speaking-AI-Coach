import Foundation

struct IELTSTest: Codable, Identifiable {
    let id: String
    let topic: String
    let part1: [String]
    let part2: Part2Topic
    let part3: [String]
}

struct Part2Topic: Codable {
    let topic: String
    let cues: [String]
}
