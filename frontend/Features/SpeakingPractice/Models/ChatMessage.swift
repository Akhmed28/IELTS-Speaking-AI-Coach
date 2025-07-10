// В файле SpeakingPractice/Models/ChatMessage.swift

import Foundation

// Действие для кнопок в чате
struct ChatAction {
    let title: String
    let perform: () -> Void
}

// НАША ЕДИНСТВЕННАЯ И ОСНОВНАЯ СТРУКТУРА ДЛЯ СООБЩЕНИЙ
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    var content: String
    var isTyping: Bool
    let timestamp: Date
    
    // Non-codable property
    var action: ChatAction?
    
    // Перечисление для ролей
    enum Role: String, Codable, CaseIterable {
        case user
        case assistant
        case system
        case error
    }

    // MARK: - Initialization
    init(id: UUID = UUID(), role: Role, content: String, isTyping: Bool = false, timestamp: Date = Date(), action: ChatAction? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.isTyping = isTyping
        self.timestamp = timestamp
        self.action = action
    }
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case id, role, content, isTyping, timestamp
    }
    
    // Custom encoding to handle non-codable action property
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(isTyping, forKey: .isTyping)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    // Custom decoding to handle non-codable action property
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        isTyping = try container.decode(Bool.self, forKey: .isTyping)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        action = nil
    }
}

// Computed property for typing indicator (for UI only)
extension ChatMessage {
    var isTypingIndicator: Bool {
        content == "..." || content.isEmpty
    }
}

// MARK: - UI Helper Properties
extension ChatMessage {
    var isUser: Bool { role == .user }
}
