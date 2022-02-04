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
    func prepare(completion: @escaping (Result<Void, AppError>) -> Void) {
        do {
           try loadPersistentStore(completion: completion)
        } catch {
            completion(.failure(error as? AppError ?? .databaseCorrupted(nil)))
        }
    }
    func rebuild(completion: @escaping (Result<Void, AppError>) -> Void) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            completion(.failure(.databaseCorrupted("PersistentContainer was not set up properly.")))
            return
        }
        DispatchQueue.global().async {
            do {
                try NSPersistentStoreCoordinator.destroyStore(at: storeURL)
            } catch {
                completion(.failure(error as? AppError ?? .databaseCorrupted(nil)))
            }
            container.loadPersistentStores { _, error in
                guard error == nil else {
                    let message = "Was unable to load store \(String(describing: error))."
                    completion(.failure(.databaseCorrupted(message)))
                    return
                }
                completion(.success(()))
            }
        }
    }
    private func loadPersistentStore(completion: @escaping (Result<Void, AppError>) -> Void) throws {
        try migrateStoreIfNeeded { result in
            switch result {
            case .success:
                container.loadPersistentStores { _, error in
                    guard error == nil else {
                        let message = "Was unable to load store \(String(describing: error))."
                        completion(.failure(.databaseCorrupted(message)))
                        return
                    }
                    completion(.success(()))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    private func migrateStoreIfNeeded(completion: @escaping (Result<Void, AppError>) -> Void) throws {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            throw AppError.databaseCorrupted("PersistentContainer was not set up properly.")
        }

        if try migrator.requiresMigration(at: storeURL, toVersion: try CoreDataMigrationVersion.current()) {
            DispatchQueue.global().async {
                do {
                    try migrator.migrateStore(at: storeURL, toVersion: try CoreDataMigrationVersion.current())
                } catch {
                    completion(.failure(error as? AppError ?? .databaseCorrupted(nil)))
                }
                completion(.success(()))
            }
        } else {
            completion(.success(()))
        }
    }
}

// MARK: Definition
protocol ManagedObjectProtocol {
    associatedtype Entity
    func toEntity() -> Entity
}

protocol ManagedObjectConvertible {
    associatedtype ManagedObject: NSManagedObject, ManagedObjectProtocol

    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> ManagedObject
}

protocol GalleryIdentifiable: NSManagedObject {
    var gid: String { get set }
}
