import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID = UUID()
    var startDate: Date
    var topic: String
    
    // --- FIX: Add a field to associate the conversation with a user ---
    var userEmail: String = ""
    
    var serverId: Int?
    
    var isComplete: Bool = false
    var finalFeedback: String? = nil
    var fluencyScore: Int = 0
    var vocabularyScore: Int = 0
    var grammarScore: Int = 0
    var pronunciationScore: Int = 0
    var overallBandScore: Double = 0.0
    
    @Relationship(deleteRule: .cascade)
    var messages: [Message] = []
    
    // --- FIX: Update the initializer to include the user's email ---
    init(startDate: Date, topic: String, userEmail: String) {
        self.startDate = startDate
        self.topic = topic
        self.userEmail = userEmail
    }
}

extension Conversation {
    static var deletedServerIDs: Set<Int> {
        get {
            let array = UserDefaults.standard.array(forKey: "deletedServerIDs") as? [Int] ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "deletedServerIDs")
        }
    }
    
    static func markAsDeleted(serverId: Int) {
        var deletedIDs = deletedServerIDs
        deletedIDs.insert(serverId)
        deletedServerIDs = deletedIDs
    }
    
    static func markServerIDDeleted(_ id: Int) {
        var set = deletedServerIDs
        set.insert(id)
        deletedServerIDs = set
    }
    
    static func unmarkServerIDDeleted(_ id: Int) {
        var set = deletedServerIDs
        set.remove(id)
        deletedServerIDs = set
    }
}
