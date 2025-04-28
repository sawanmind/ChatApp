import SwiftUI
import SwiftData

@MainActor
final class ModelContextProvider {
    static let shared = ModelContextProvider()
    
    private(set) var store: SwiftDataStore
    private(set) var container: ModelContainer
    
    var mainContext: ModelContext {
        container.mainContext
    }
    
    private init() {
        do {
            store = try SwiftDataStore.makeStore()
            container = store.modelContainer
         
            if let container = try? ModelContainer(for: MessageEntity.self) {
                print(container.configurations.first?.url.path ?? "No path")
            }
            
            Logger.log("SwiftData store initialized successfully", level: .info)
            
        } catch {
            Logger.log("Failed to initialize SwiftData store: \(error)", level: .error)
            fatalError("Failed to initialize SwiftData store: \(error)")
        }
    }
}
