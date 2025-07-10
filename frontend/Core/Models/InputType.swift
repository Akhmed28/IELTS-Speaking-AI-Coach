import Foundation

// We deleted PracticeSession, so this enum should be standalone or part of another model if only used there.
// For now, let's keep it for potential future use or integration with the Message model.
enum InputType: String, Codable {
    case speech
    case text
}
