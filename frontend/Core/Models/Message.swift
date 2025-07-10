import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var content: String
    var role: String
    var timestamp: Date
    var conversation: Conversation?
    
    init(content: String, role: String, timestamp: Date) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = timestamp
    }
}
