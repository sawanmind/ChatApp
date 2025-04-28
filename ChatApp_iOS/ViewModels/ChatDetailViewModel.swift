import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class ChatDetailViewModel: ObservableObject {
    @Published private(set) var isSending = false
    @Published var messageText = ""
    @Published private(set) var messages: [MessageEntity] = []
    @Published private(set) var syncStatus: SyncStatus = .completed
    
    private let store: SwiftDataStoring
    private let syncManager: SyncManaging
    private(set) var bot: ChatBot
    private var cancellables = Set<AnyCancellable>()
    private var processedMessageIds = Set<String>()
    
    init(bot: ChatBot, store: SwiftDataStoring, syncManager: SyncManaging) {
        self.bot = bot
        self.store = store
        self.syncManager = syncManager
        
        setupStoreObservation()
        setupSyncObservation()
        Task {
            await fetchMessages()
        }
        
    }
    
    func sendMessage() async throws {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            let messageId = UUID().uuidString
            let message = MessageEntity(
                id: messageId,
                content: messageText,
                timestamp: Date(),
                isSynced: false,
                isRead: true,
                sender: "currentUser",
                receiverId: bot.id
            )
            
            processedMessageIds.insert(messageId)
            
            try await store.save(message)
            messageText = ""
            
            try await syncManager.syncPendingMessages()
            
            await fetchMessages()
            
        } catch {
            Logger.log("Failed to save/sync message: \(error)", level: .error)
            throw error
        }
    }
    
    private func setupStoreObservation() {
        NotificationCenter.default
            .publisher(for: .swiftDataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchMessages()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSyncObservation() {
        syncManager.syncStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
            }
            .store(in: &cancellables)
    }
    
    private func fetchMessages() async {
        do {
            let botId = bot.id
            let predicate = #Predicate<MessageEntity> { message in
                message.receiverId == botId || message.sender == botId
            }
            
            let fetchedMessages = try await store.fetch(
                MessageEntity.self,
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp)]
            )
            
            let newMessages = fetchedMessages.filter { message in
                !processedMessageIds.contains(message.id)
            }
            
            newMessages.forEach { message in
                processedMessageIds.insert(message.id)
            }
            
            messages = fetchedMessages
            
        } catch {
            Logger.log("Failed to fetch messages: \(error)", level: .error)
        }
    }
   
    deinit {
        cancellables.removeAll()
    }
}

