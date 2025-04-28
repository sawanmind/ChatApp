import Foundation
import Combine


enum SocketEvent: String {
    case message
    case connection
    case disconnection
}

enum SocketError: Error {
    case notConnected
    case invalidData
    case connectionFailed
    case networkUnavailable
}

protocol SocketConnecting: AnyObject {
    var isConnected: Bool { get }
    var connectionStatePublisher: AnyPublisher<Bool, Never> { get }
    func connect() async throws
    func disconnect()
    func send(_ message: String) async throws
    func listen(completion: @escaping (Result<String, Error>) -> Void)
}
