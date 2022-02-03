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
    func setup(completion: @escaping () -> Void) {
        loadPersistentStore {
            completion()
        }
    }
    private func loadPersistentStore(completion: @escaping () -> Void) {
        migrateStoreIfNeeded {
            container.loadPersistentStores { _, error in
                guard error == nil else {
                    let message = "Was unable to load store \(String(describing: error))."
                    Logger.error(message)
                    fatalError(message)
                }

                completion()
            }
        }
    }
    private func migrateStoreIfNeeded(completion: @escaping () -> Void) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            let message = "PersistentContainer was not set up properly."
            Logger.error(message)
            fatalError(message)
        }

        if migrator.requiresMigration(at: storeURL, toVersion: CoreDataMigrationVersion.current) {
            DispatchQueue.global(qos: .userInitiated).async {
                migrator.migrateStore(at: storeURL, toVersion: CoreDataMigrationVersion.current)

                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            completion()
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
