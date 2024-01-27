//
//  Persistence.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/04.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    let migrator = CoreDataMigrator()

    let container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")
        let description = container.persistentStoreDescriptions.first
        description?.shouldInferMappingModelAutomatically = false
        description?.shouldMigrateStoreAutomatically = false
        return container
    }()
}

// MARK: Preparation
extension PersistenceController {
    public func prepare() async -> AppError? {
        do {
           return try await loadPersistentStore()
        } catch {
            return error as? AppError ?? .databaseCorrupted(nil)
        }
    }

    public func rebuild() async -> AppError? {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return .databaseCorrupted("PersistentContainer was not set up properly.")
        }
        do {
            try NSPersistentStoreCoordinator.destroyStore(at: storeURL)
        } catch {
            return error as? AppError ?? .databaseCorrupted(nil)
        }
        return await container.loadPersistentStoresAsync()
    }

    private func loadPersistentStore() async throws -> AppError? {
        if let appError = try migrateStoreIfNeeded() { return appError }
        guard container.persistentStoreCoordinator.persistentStores.isEmpty else { return nil }
        return await container.loadPersistentStoresAsync()
    }

    private func migrateStoreIfNeeded() throws -> AppError? {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            throw AppError.databaseCorrupted("PersistentContainer was not set up properly.")
        }

        guard try migrator.requiresMigration(at: storeURL, toVersion: try CoreDataMigrationVersion.current())
        else { return nil }

        do {
            try migrator.migrateStore(at: storeURL, toVersion: try CoreDataMigrationVersion.current())
        } catch {
            return error as? AppError ?? .databaseCorrupted(nil)
        }
        return nil
    }
}

extension NSPersistentCloudKitContainer {
    func loadPersistentStoresAsync() async -> AppError? {
        await withCheckedContinuation { continuation in
            loadPersistentStores { _, error in
                continuation.resume(
                    returning: error.map({ .databaseCorrupted("Was unable to load store \($0).") })
                )
            }
        }
    }
}

// MARK: Definition
protocol ModelConvertible {
    associatedtype Model
    func toModel() -> Model
}

protocol ManagedObjectConvertible {
    associatedtype ManagedObject: NSManagedObject, ModelConvertible

    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> ManagedObject
}

protocol GalleryIdentifiable: NSManagedObject {
    var gid: String { get set }
}
