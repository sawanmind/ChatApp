import SwiftData
import Foundation

@Model
final class MessageEntity {
    @Attribute(.unique) var id: String
    var content: String
    var timestamp: Date
    var isSynced: Bool
    var isRead: Bool
    var sender: String
    var receiverId: String?
    
    init(
        id: String = UUID().uuidString,
        content: String,
        timestamp: Date = Date(),
        isSynced: Bool = false,
        isRead: Bool = false,
        sender: String,
        receiverId: String? = nil
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isSynced = isSynced
        self.isRead = isRead
        self.sender = sender
        self.receiverId = receiverId
    }
}

struct ServerMessage: Codable {
    let botId: String
    let content: String
    let isResponse: Bool
    let id: String
    let timestamp: String?
}
