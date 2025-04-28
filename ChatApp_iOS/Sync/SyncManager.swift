import Foundation
import SwiftData
import Combine

protocol SyncManaging: AnyObject {
    var syncStatusPublisher: AnyPublisher<SyncStatus, Never> { get }
    func setupMessageListener()
    func syncPendingMessages() async throws
}

protocol SyncStatusReporting {
    var syncStatusPublisher: AnyPublisher<SyncStatus, Never> { get }
}

enum SyncStatus {
    case syncing
    case completed
    case failed(Error)
}

enum SyncError: Error {
    case socketNotConnected
    case serverError
    case invalidData
    case saveFailed
}

final class SyncManager: SyncManaging {
    private let store: SwiftDataStoring
    private let socketManager: SocketConnecting
    private let networkChecker: NetworkMonitoring
    private let maxRetries = 3
    private let syncStatusSubject = CurrentValueSubject<SyncStatus, Never>(.completed)
    private var cancellables = Set<AnyCancellable>()
    private var hasSetupListener = false

    var syncStatusPublisher: AnyPublisher<SyncStatus, Never> {
        syncStatusSubject.eraseToAnyPublisher()
    }

    init(
        store: SwiftDataStoring,
        socketManager: SocketConnecting,
        networkChecker: NetworkMonitoring = NetworkReachability.shared
    ) {
        self.store = store
        self.socketManager = socketManager
        self.networkChecker = networkChecker

        setupMessageListener()
        setupNetworkMonitoring()
    }

    func setupMessageListener() {
        guard !hasSetupListener else { return }
        hasSetupListener = true

        socketManager.listen { [weak self] result in
            Task { [weak self] in
                switch result {
                case .success(let message):
                    try await self?.handleIncomingServerMessage(message)
                case .failure(let error):
                    self?.syncStatusSubject.send(.failed(error))
                }
            }
        }
    }

    func syncPendingMessages() async throws {
        guard socketManager.isConnected else {
            throw SyncError.socketNotConnected
        }

        syncStatusSubject.send(.syncing)

        do {
            let predicate = #Predicate<MessageEntity> { !$0.isSynced }

            let pendingMessages = try await store.fetch(
                MessageEntity.self,
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp)]
            )

            for message in pendingMessages {
                try await syncMessageToServer(message)
            }

            syncStatusSubject.send(.completed)

        } catch {
            syncStatusSubject.send(.failed(error))
            throw error
        }
    }

    private func setupNetworkMonitoring() {
        networkChecker.networkStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    Task {
                        try? await self?.handleNetworkReturn()
                    }
                } else {
                    self?.handleNetworkLoss()
                }
            }
            .store(in: &cancellables)

        networkChecker.startMonitoring()
    }

    private func handleNetworkReturn() async throws {
        try await ensureConnection()
        try await syncPendingMessages()
    }

    private func handleNetworkLoss() {
        socketManager.disconnect()
    }

    private func ensureConnection(retries: Int = 0) async throws {
        guard !socketManager.isConnected else { return }

        do {
            try await socketManager.connect()
        } catch {
            if retries < maxRetries {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                try await ensureConnection(retries: retries + 1)
            } else {
                throw SyncError.socketNotConnected
            }
        }
    }

    private func syncMessageToServer(_ message: MessageEntity) async throws {
        let payload: [String: Any] = [
            "botId": message.receiverId ?? "",
            "content": message.content,
            "id": message.id,
            "isResponse": false,
            "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

        try await socketManager.send(jsonString)

        message.isSynced = true
        try await store.update(message)
    }

    private func handleIncomingServerMessage(_ message: String) async throws {
        do {
            guard let data = message.data(using: .utf8) else {
                throw SyncError.invalidData
            }

            let serverMessage = try JSONDecoder().decode(ServerMessage.self, from: data)

            guard serverMessage.isResponse else {
                return
            }

            let newMessage = MessageEntity(
                id: serverMessage.id,
                content: serverMessage.content,
                timestamp: Date(),
                isSynced: true,
                isRead: false,
                sender: serverMessage.botId,
                receiverId: "currentUser"
            )

            try await store.save(newMessage)

        } catch let decodingError as DecodingError {
            throw SyncError.invalidData
        } catch {
            throw SyncError.invalidData
        }
    }
}

