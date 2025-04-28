import SwiftUI
import SwiftData

final class ChatListViewBuilder {
    @MainActor
    static func make() -> ChatListView {
        let chatProvider = DefaultChatProvider()
        let modelContext = ModelContextProvider.shared.mainContext
        
        let viewModel = ChatListViewModel(
            chatProvider: chatProvider,
            modelContext: modelContext
        )
        
        return ChatListView(viewModel: viewModel)
    }
}
