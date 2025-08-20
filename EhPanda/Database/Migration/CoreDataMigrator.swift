//
//  CoreDataMigrator.swift
//  CoreDataMigration-Example
//

import CoreData

protocol CoreDataMigratorProtocol {
    func requiresMigration(at storeURL: URL, toVersion version: CoreDataMigrationVersion) throws -> Bool
    func migrateStore(at storeURL: URL, toVersion version: CoreDataMigrationVersion) throws
}

class CoreDataMigrator: CoreDataMigratorProtocol {
    func requiresMigration(at storeURL: URL, toVersion version: CoreDataMigrationVersion) throws -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else { return false }
        return (try CoreDataMigrationVersion.compatibleVersionForStoreMetadata(metadata) != version)
    }

    func migrateStore(at storeURL: URL, toVersion version: CoreDataMigrationVersion) throws {
        try forceWALCheckpointingForStore(at: storeURL)

        var currentURL = storeURL
        let migrationSteps = try migrationStepsForStore(at: storeURL, toVersion: version)

        for migrationStep in migrationSteps {
            let manager = NSMigrationManager(
                sourceModel: migrationStep.sourceModel, destinationModel: migrationStep.destinationModel
            )
            let destinationURL = FileUtil.temporaryDirectory.appendingPathComponent(UUID().uuidString)

            do {
                try manager.migrateStore(
                    from: currentURL, sourceType: NSSQLiteStoreType, options: nil,
                    with: migrationStep.mappingModel, toDestinationURL: destinationURL,
                    destinationType: NSSQLiteStoreType, destinationOptions: nil
                )
            } catch {
                let message = "Failed attempting to migrate from \(migrationStep.sourceModel) "
                + "to \(migrationStep.destinationModel), error: \(error)."
                throw AppError.databaseCorrupted(message)
            }

            if currentURL != storeURL {
                try NSPersistentStoreCoordinator.destroyStore(at: currentURL)
            }

            currentURL = destinationURL
        }

        try NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)

        if currentURL != storeURL {
            try NSPersistentStoreCoordinator.destroyStore(at: currentURL)
        }
    }

    private func migrationStepsForStore(
        at storeURL: URL, toVersion destinationVersion: CoreDataMigrationVersion
    ) throws -> [CoreDataMigrationStep] {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = try CoreDataMigrationVersion.compatibleVersionForStoreMetadata(metadata)
        else {
            throw AppError.databaseCorrupted("Unknown store version at URL \(storeURL).")
        }
        return try migrationSteps(fromSourceVersion: sourceVersion, toDestinationVersion: destinationVersion)
    }

    private func migrationSteps(
        fromSourceVersion sourceVersion: CoreDataMigrationVersion,
        toDestinationVersion destinationVersion: CoreDataMigrationVersion
    ) throws -> [CoreDataMigrationStep] {
        var sourceVersion = sourceVersion
        var migrationSteps = [CoreDataMigrationStep]()

        while sourceVersion != destinationVersion, let nextVersion = sourceVersion.nextVersion() {
            let migrationStep = try CoreDataMigrationStep(sourceVersion: sourceVersion, destinationVersion: nextVersion)
            migrationSteps.append(migrationStep)

            sourceVersion = nextVersion
        }

        return migrationSteps
    }

    func forceWALCheckpointingForStore(at storeURL: URL) throws {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let currentModel = NSManagedObjectModel.compatibleModelForStoreMetadata(metadata)
        else { return }

        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
            let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            let store = try persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
            try persistentStoreCoordinator.remove(store)
        } catch {
            throw AppError.databaseCorrupted("Failed to force WAL checkpointing, error: \(error).")
        }
    }
}

private extension CoreDataMigrationVersion {
    static func compatibleVersionForStoreMetadata(_ metadata: [String: Any]) throws -> CoreDataMigrationVersion? {
        let compatibleVersion = try CoreDataMigrationVersion.allCases.first {
            let model = try NSManagedObjectModel.managedObjectModel(forResource: $0.rawValue)
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        return compatibleVersion
    }
}
