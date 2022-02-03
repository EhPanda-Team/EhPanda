//
//  Model5toModel6MigrationPolicy.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/24.
//

import CoreData

// swiftlint:disable type_name
final class GalleryMO5toGalleryMO6MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sourceInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sourceInstance, in: mapping, manager: manager)
        guard let destinationGalleryMO = manager.destinationInstances(
            forEntityMappingName: mapping.name, sourceInstances: [sourceInstance]
        ).first else {
            let message = "Was expected a GalleryMO."
            Logger.error(message)
            fatalError(message)
        }
        guard let coverURLString = sourceInstance.value(forKey: "coverURL") as? String,
              let galleryURLString = sourceInstance.value(forKey: "galleryURL") as? String,
              let coverURL = URL(string: coverURLString), let galleryURL = URL(string: galleryURLString)
        else { return }
        destinationGalleryMO.setValue(coverURL, forKey: "coverURL")
        destinationGalleryMO.setValue(galleryURL, forKey: "galleryURL")
    }
}

final class GalleryDetailMO5toGalleryDetailMO6MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sourceInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sourceInstance, in: mapping, manager: manager)
        guard let destinationGalleryDetailMO = manager.destinationInstances(
            forEntityMappingName: mapping.name, sourceInstances: [sourceInstance]
        ).first else {
            let message = "Was expected a GalleryDetailMO."
            Logger.error(message)
            fatalError(message)
        }
        let parentURLString = sourceInstance.value(forKey: "parentURL") as? String
        let archiveURLString = sourceInstance.value(forKey: "archiveURL") as? String
        guard let coverURLString = sourceInstance.value(forKey: "coverURL") as? String,
              let coverURL = URL(string: coverURLString)
        else { return }
        destinationGalleryDetailMO.setValue(URL(string: parentURLString ?? ""), forKey: "parentURL")
        destinationGalleryDetailMO.setValue(URL(string: archiveURLString ?? ""), forKey: "archiveURL")
        destinationGalleryDetailMO.setValue(coverURL, forKey: "coverURL")
    }
}

final class GalleryStateMO5toGalleryStateMO6MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sourceInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sourceInstance, in: mapping, manager: manager)
        guard let destinationGalleryStateMO = manager.destinationInstances(
            forEntityMappingName: mapping.name, sourceInstances: [sourceInstance]
        ).first else {
            let message = "Was expected a GalleryStateMO."
            Logger.error(message)
            fatalError(message)
        }
        let previews = sourceInstance.value(forKey: "previews") as? [Int: String]
        let thumbnails = sourceInstance.value(forKey: "thumbnails") as? [Int: String]
        let contents = sourceInstance.value(forKey: "contents") as? [Int: String]
        let originalContents = sourceInstance.value(forKey: "originalContents") as? [Int: String]
        destinationGalleryStateMO.setValue(previews?.mapToURLs, forKey: "previewURLs")
        destinationGalleryStateMO.setValue(thumbnails?.mapToURLs, forKey: "thumbnailURLs")
        destinationGalleryStateMO.setValue(contents?.mapToURLs, forKey: "imageURLs")
        destinationGalleryStateMO.setValue(originalContents?.mapToURLs, forKey: "originalImageURLs")
    }
}
// swiftlint:enable type_name

private extension Dictionary where Value == String {
    func mapToURLs() -> [Key: URL] {
        compactMap { (key, value) -> (Key, URL)? in
            if let url = URL(string: value) {
                return (key, url)
            } else {
                return nil
            }
        }
        .reduce(into: [:]) { $0[$1.0] = $1.1 }
    }
}
