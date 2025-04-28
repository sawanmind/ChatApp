import Foundation

protocol ChatProviding {
    func getDefaultBots() -> [ChatBot]
}

final class DefaultChatProvider: ChatProviding {
    func getDefaultBots() -> [ChatBot] {
        return [
            ChatBot(id: "1", botName: "Support Bot", botType: .support, lastMessage: nil, unreadCount: 0, avatarImage: "headphones.circle.fill", timestamp: nil),
            ChatBot(id: "2", botName: "Sales Bot", botType: .sales, lastMessage: nil, unreadCount: 0, avatarImage: "cart.circle.fill", timestamp: nil),
            ChatBot(id: "3", botName: "FAQ Bot", botType: .faq, lastMessage: nil, unreadCount: 0, avatarImage: "questionmark.circle.fill", timestamp: nil)
        ]
    }
}
