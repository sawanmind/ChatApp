
import SwiftUI

struct ChatListView: View {
    @ObservedObject private var viewModel: ChatListViewModel
    
    init(viewModel: ChatListViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.chats.isEmpty {
                    EmptyChatsView()
                } else {
                    List(viewModel.chats) { chat in
                        ChatRowView(chat: chat) {
                            viewModel.markAsRead(chat.id)
                        }
                    }
                    .refreshable {
                        viewModel.refreshChats()
                    }
                }
            }
            .navigationTitle("Chats")
        }
        .onAppear {
            viewModel.refreshChats()
        }
    }
}


struct EmptyChatsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Active Chats")
                .font(.headline)
            
            Text("Your conversations will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct ChatRowView: View {
    let chat: ChatBot
    let onAppear: () -> Void
    
    var body: some View {
        NavigationLink(destination: ChatDetailViewBuilder.make(chat)) {
            HStack(spacing: 12) {
                ChatAvatarView(imageName: chat.avatarImage, botType: chat.botType)
                ChatContentView(chat: chat)
            }
            .padding(.vertical, 8)
        }
        .onAppear(perform: onAppear)
    }
}

struct ChatAvatarView: View {
    let imageName: String
    let botType: BotType
    
    var body: some View {
        Image(systemName: imageName)
            .font(.system(size: 40))
            .foregroundColor(botType.color)
            .frame(width: 50, height: 50)
    }
}

struct ChatContentView: View {
    let chat: ChatBot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ChatHeaderView(name: chat.botName, timestamp: chat.timestamp)
            if let lastMessage = chat.lastMessage {
                ChatPreviewView(message: lastMessage, unreadCount: chat.unreadCount)
            }
        }
    }
}

struct ChatHeaderView: View {
    let name: String
    let timestamp: Date?
    
    var body: some View {
        HStack {
            Text(name)
                .font(.headline)
            Spacer()
            
            if let timestamp = timestamp {
                Text(timeString(from: timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ChatPreviewView: View {
    let message: String
    let unreadCount: Int
    
    var body: some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Spacer()
            
            if unreadCount > 0 {
                UnreadBadge(count: unreadCount)
            }
        }
    }
}

struct UnreadBadge: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.blue))
            .minimumScaleFactor(0.5)
    }
}

