import Network
import Combine
import Foundation

protocol NetworkMonitoring {
    var isConnected: Bool { get }
    var networkStatusPublisher: AnyPublisher<Bool, Never> { get }
    func startMonitoring()
    func stopMonitoring()
}

final class NetworkReachability: NetworkMonitoring {
    static let shared = NetworkReachability()
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private let statusSubject = CurrentValueSubject<Bool, Never>(false)
    private let lock = NSLock()
    
    var networkStatusPublisher: AnyPublisher<Bool, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    private(set) var isConnected: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.statusSubject.send(self.isConnected)
                self.onNetworkStatusChanged?(self.isConnected)
            }
        }
    }
    
    var onNetworkStatusChanged: ((Bool) -> Void)?
    
    private(set) var isMonitoring = false {
        didSet {
            Logger.log("Network monitoring state: \(isMonitoring)", level: .debug)
        }
    }
    
    private init() {
        monitor = NWPathMonitor()
        setupMonitor()
    }
    
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let isConnected = path.status == .satisfied
            let interfaces = path.availableInterfaces.map { $0.type }
            
            Logger.log("""
                Network status changed:
                - Connected: \(isConnected)
                - Interface: \(interfaces)
                - Is Expensive: \(path.isExpensive)
                - Is Constrained: \(path.isConstrained)
                """, level: .info)
            
            DispatchQueue.main.async {
                if self.isConnected != isConnected {
                    Logger.log("Network connection state changed from \(self.isConnected) to \(isConnected)", level: .info)
                    self.isConnected = isConnected
                }
            }
        }
    }
    
    func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isMonitoring else {
            Logger.log("Network monitoring already active", level: .debug)
            return
        }
        
        monitor.start(queue: monitorQueue)
        isMonitoring = true
        
        let initialStatus = monitor.currentPath.status == .satisfied
        DispatchQueue.main.async {
            self.isConnected = initialStatus
        }
        
        Logger.log("Network monitoring started with initial status: \(initialStatus)", level: .info)
    }
    
    func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isMonitoring else { return }
        
        monitor.cancel()
        isMonitoring = false
        Logger.log("Network monitoring stopped", level: .info)
    }
    
    deinit {
        stopMonitoring()
        print("NetworkReachability deinit")
    }
}

extension NWInterface.InterfaceType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}
