
import SwiftUI
import SwiftData

struct ChatDetailView: View {
    @StateObject private var viewModel: ChatDetailViewModel
    @FocusState private var isInputFocused: Bool

    init(bot: ChatBot, store: SwiftDataStoring, syncManager: SyncManaging) {
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(bot: bot, store: store, syncManager: syncManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.messages.isEmpty {
                EmptyMessagesView()
            } else {
                MessageListView(messages: viewModel.messages)
                Spacer()
            }
            
            MessageInputView(
                text: $viewModel.messageText,
                isFocused: _isInputFocused,
                isSending: viewModel.isSending
            ) {
                Task {
                    try await viewModel.sendMessage()
                }
            }
        }
        .navigationTitle(viewModel.bot.botName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyMessagesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No messages yet")
                .font(.headline)
            
            Text("Start a new conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct MessageListView: View {
    let messages: [MessageEntity]
    
    @State private var lastMessageId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages, id: \.id) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: MessageEntity
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading) {
                Text(message.content)
                    .padding(12)
                    .background(messageBackground)
                    .foregroundColor(messageTextColor)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    if isFromCurrentUser {
                        syncStatusIcon
                    }
                    
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }

    private var isFromCurrentUser: Bool {
        message.sender == "currentUser"
    }

    private var messageBackground: Color {
        isFromCurrentUser ? .blue : .gray.opacity(0.2)
    }

    private var messageTextColor: Color {
        isFromCurrentUser ? .white : .primary
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }

    private var syncStatusIcon: some View {
        Group {
            if message.isSynced {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

struct MessageInputView: View {
    @Binding var text: String
    @FocusState var isFocused: Bool
    let isSending: Bool
    let onSend: () async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .disabled(isSending)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    private func sendMessage() {
        Task {
            await onSend()
        }
    }
}
