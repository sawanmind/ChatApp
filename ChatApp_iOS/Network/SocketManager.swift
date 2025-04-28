import Foundation
import Combine

final class SocketManager: NSObject, SocketConnecting {
    private let url: URL
    private let networkMonitor: NetworkMonitoring
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession!
    
    private let connectionStateSubject = CurrentValueSubject<Bool, Never>(false)
    var connectionStatePublisher: AnyPublisher<Bool, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    private var messageHandler: ((Result<String, Error>) -> Void)?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var isConnected = false {
        didSet {
            connectionStateSubject.send(isConnected)
        }
    }
    
    private var isConnecting = false
    
    init(url: URL, networkMonitor: NetworkMonitoring) {
        self.url = url
        self.networkMonitor = networkMonitor
        super.init()
        setupSession()
        setupNetworkMonitoring()
    }

    deinit {
        disconnect()
        reconnectTask?.cancel()
        pingTask?.cancel()
        networkMonitor.stopMonitoring()
    }

    func connect() async throws {
        guard !isConnected && !isConnecting else { return }
        
        isConnecting = true
        defer { isConnecting = false }

        guard networkMonitor.isConnected else {
            throw SocketError.networkUnavailable
        }

        socket = session.webSocketTask(with: url)
        socket?.resume()
        isConnected = true
        startListening()
        startPinging()
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isConnected = false
        isConnecting = false
        messageHandler = nil
        reconnectTask?.cancel()
        pingTask?.cancel()
    }

    func send(_ message: String) async throws {
        guard isConnected else {
            throw SocketError.notConnected
        }

        try await socket?.send(.string(message))
    }

    func listen(completion: @escaping (Result<String, Error>) -> Void) {
        messageHandler = completion
        startListening()
    }

    private func setupSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    private func setupNetworkMonitoring() {
        networkMonitor.networkStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                if isConnected {
                    self.handleNetworkReturn()
                } else {
                    self.handleNetworkLoss()
                }
            }
            .store(in: &cancellables)
        
        networkMonitor.startMonitoring()
    }

    private func handleNetworkReturn() {
        guard !isConnected else { return }

        reconnectTask?.cancel()
        reconnectTask = Task {
            var delay: UInt64 = 1
            while !isConnected {
                do {
                    try await connect()
                    break
                } catch {
                    try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                    delay = min(delay * 2, 30)
                }
            }
        }
    }

    private func handleNetworkLoss() {
        if isConnected {
            disconnect()
        }
    }

    private func startListening() {
        Task {
            while isConnected {
                do {
                    guard let result = try await socket?.receive() else { continue }
                    switch result {
                    case .string(let text):
                        messageHandler?(.success(text))
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            messageHandler?(.success(text))
                        } else {
                            messageHandler?(.failure(SocketError.invalidData))
                        }
                    @unknown default:
                        messageHandler?(.failure(SocketError.invalidData))
                    }
                } catch {
                    if (error as NSError).code != NSURLErrorCancelled {
                        messageHandler?(.failure(error))
                    }
                    break
                }
            }
        }
    }

    private func startPinging() {
        pingTask?.cancel()
        pingTask = Task {
            while isConnected {
                await MainActor.run {
                    socket?.sendPing { error in
                        if let error = error {
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            }
        }
    }
}

extension SocketManager: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        isConnected = true
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        isConnected = false
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}

