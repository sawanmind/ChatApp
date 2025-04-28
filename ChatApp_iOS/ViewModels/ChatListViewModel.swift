import Foundation
import Combine
import SwiftData

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published private(set) var chats: [ChatBot] = []
    
    private let chatProvider: ChatProviding
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    private var messagesDescriptor: FetchDescriptor<MessageEntity> {
        FetchDescriptor<MessageEntity>(sortBy: [SortDescriptor(\.timestamp)])
    }

    init(
        chatProvider: ChatProviding = DefaultChatProvider(),
        modelContext: ModelContext
    ) {
        self.chatProvider = chatProvider
        self.modelContext = modelContext
        
        setupInitialState()
        setupStoreObservation()
    }
    
    func refreshChats() {
        Task {
            await updateChatsWithLatestMessages()
        }
    }
    
    func markAsRead(_ chatId: String) {
        Task {
            do {
                let predicate = #Predicate<MessageEntity> {
                    $0.sender == chatId && !$0.isRead
                }
                let descriptor = FetchDescriptor(predicate: predicate)
                let unreadMessages = try modelContext.fetch(descriptor)
                
                for message in unreadMessages {
                    message.isRead = true
                }
                
                try modelContext.save()
                await updateChatsWithLatestMessages()
            } catch {
                Logger.log("Failed to mark messages as read: \(error)", level: .error)
            }
        }
    }
    
    private func setupInitialState() {
        chats = chatProvider.getDefaultBots()
        refreshChats()
    }
    
    private func setupStoreObservation() {
        NotificationCenter.default
            .publisher(for: .swiftDataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshChats()
            }
            .store(in: &cancellables)
    }

    private func updateChatsWithLatestMessages() async {
        do {
            let messages = try modelContext.fetch(messagesDescriptor)
            
            let groupedMessages = Dictionary(grouping: messages) { message in
                message.sender
            }
            
            let updatedChats = chats.map { chat in
                guard let chatMessages = groupedMessages[chat.id] else {
                    return chat
                }

                let sortedMessages = chatMessages.sorted { $0.timestamp > $1.timestamp }

                if let latestMessage = sortedMessages.first(where: { !$0.isRead }) {
                    let unreadCount = sortedMessages.filter { !$0.isRead }.count

                    return ChatBot(
                        id: chat.id,
                        botName: chat.botName,
                        botType: chat.botType,
                        lastMessage: latestMessage.content,
                        unreadCount: unreadCount,
                        avatarImage: chat.avatarImage,
                        timestamp: latestMessage.timestamp
                    )
                } else {
                    return ChatBot(
                        id: chat.id,
                        botName: chat.botName,
                        botType: chat.botType,
                        lastMessage: sortedMessages.first?.content ?? "",
                        unreadCount: 0,
                        avatarImage: chat.avatarImage,
                        timestamp: sortedMessages.first?.timestamp ?? Date()
                    )
                }
            }
            
            self.chats = updatedChats

        } catch {
            Logger.log("Failed to update chats: \(error)", level: .error)
        }
    }
}

