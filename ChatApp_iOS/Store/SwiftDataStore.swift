import Foundation
import SwiftData

protocol SwiftDataStoring {
    func save<T: PersistentModel>(_ object: T) async throws
    func update<T: PersistentModel>(_ object: T) async throws
    func delete<T: PersistentModel>(_ object: T) async throws
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?, sortBy: [SortDescriptor<T>]) async throws -> [T]
    func clearAll<T: PersistentModel>(_ type: T.Type) async throws
}

@MainActor
final class SwiftDataStore: SwiftDataStoring {
    private(set) var modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }
    
    func save<T: PersistentModel>(_ object: T) async throws {
        do {
            Logger.log("Saving object of type: \(String(describing: T.self))", level: .debug)
            modelContext.insert(object)
            try modelContext.save()
            Logger.log("Save successful", level: .info)
            NotificationCenter.default.post(name: .swiftDataDidChange, object: nil)
        } catch {
            Logger.log("Failed to save: \(error)", level: .error)
            throw error
        }
    }
    
    func update<T: PersistentModel>(_ object: T) async throws {
        do {
            Logger.log("Updating object of type: \(String(describing: T.self))", level: .debug)
            try modelContext.save()
            Logger.log("Update successful", level: .info)
            NotificationCenter.default.post(name: .swiftDataDidChange, object: nil)
        } catch {
            Logger.log("Failed to update: \(error)", level: .error)
            throw error
        }
    }
    
    func delete<T: PersistentModel>(_ object: T) async throws {
        do {
            Logger.log("Deleting object of type: \(String(describing: T.self))", level: .debug)
            modelContext.delete(object)
            try modelContext.save()
            Logger.log("Delete successful", level: .info)
            NotificationCenter.default.post(name: .swiftDataDidChange, object: nil)
        } catch {
            Logger.log("Failed to delete: \(error)", level: .error)
            throw error
        }
    }
    
    func fetch<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = []
    ) async throws -> [T] {
        do {
            Logger.log("Fetching objects of type: \(String(describing: T.self))", level: .debug)
            let descriptor = FetchDescriptor(
                predicate: predicate,
                sortBy: sortBy
            )
            let results = try modelContext.fetch(descriptor)
            Logger.log("Fetch successful, found \(results.count) items", level: .info)
            return results
        } catch {
            Logger.log("Failed to fetch: \(error)", level: .error)
            throw error
        }
    }
    
    func clearAll<T: PersistentModel>(_ type: T.Type) async throws {
        do {
            Logger.log("Clearing all objects of type: \(String(describing: T.self))", level: .debug)
            let descriptor = FetchDescriptor<T>()
            let items = try modelContext.fetch(descriptor)
            items.forEach { modelContext.delete($0) }
            try modelContext.save()
            Logger.log("Clear successful", level: .info)
        } catch {
            Logger.log("Failed to clear: \(error)", level: .error)
            throw error
        }
    }
}

// MARK: - Store Provider
extension SwiftDataStore {
    static func makeStore() throws -> SwiftDataStore {
        let schema = Schema([MessageEntity.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        let container = try ModelContainer(
            for: schema,
            configurations: modelConfiguration
        )
        
        return SwiftDataStore(modelContainer: container)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let swiftDataDidChange = Notification.Name("swiftDataDidChange")
}
