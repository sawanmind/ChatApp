import Foundation
import SwiftUI
import SwiftData

@MainActor
final class ChatDetailViewBuilder {
    static func make(_ bot: ChatBot) -> ChatDetailView {
        let container = ModelContextProvider.shared.container
        let store = SwiftDataStore(modelContainer: container)
        
        let networkMonitor = NetworkReachability.shared
        networkMonitor.startMonitoring()
        
        let socketManager = SocketManager(
            url: URL(string: "wss://s14529.blr1.piesocket.com/v3/1?api_key=5mvPMmHnvap8kxvXXlCpNz2Jmunvh7xD3zdeHTJw")!,
            networkMonitor: networkMonitor
        )
        
        let syncManager = SyncManager(
            store: store,
            socketManager: socketManager,
            networkChecker: networkMonitor
        )
        
        Task {
            do {
                try await socketManager.connect()
                syncManager.setupMessageListener()
                try await syncManager.syncPendingMessages()
            } catch {
                Logger.log("Failed to initialize sync: \(error)", level: .error)
            }
        }
        
        return ChatDetailView(
            bot: bot,
            store: store,
            syncManager: syncManager
        )
    }
}
