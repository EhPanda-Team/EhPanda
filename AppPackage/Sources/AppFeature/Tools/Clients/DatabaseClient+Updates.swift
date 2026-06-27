import SwiftUI
import AppModels
import CoreData

// MARK: UpdateGalleryState
extension DatabaseClient {
    @MainActor func updateGalleryState(gid: String, commitChanges: @escaping (GalleryStateMO) -> Void) {
        guard gid.isValidGID else { return }
        update(
            entityType: GalleryStateMO.self, gid: gid, createIfNil: true,
            commitChanges: commitChanges
        )
    }
    @MainActor func updateGalleryState(gid: String, key: String, value: Any?) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid) { stateMO in
            stateMO.setValue(value, forKeyPath: key)
        }
    }
    @MainActor func updateGalleryTags(gid: String, tags: [GalleryTag]) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid, key: "tags", value: tags.toData())
    }
    @MainActor func updatePreviewConfig(gid: String, config: PreviewConfig) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid, key: "previewConfig", value: config.toData())
    }
    @MainActor func updateReadingProgress(gid: String, progress: Int) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid, key: "readingProgress", value: Int64(progress))
    }
    @MainActor func updateComments(gid: String, comments: [GalleryComment]) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid, key: "comments", value: comments.toData())
    }

    @MainActor func removeImageURLs(gid: String) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid) { galleryStateMO in
            galleryStateMO.imageURLs = nil
            galleryStateMO.previewURLs = nil
            galleryStateMO.thumbnailURLs = nil
            galleryStateMO.originalImageURLs = nil
        }
    }
    @MainActor func removeImageURLs() {
        batchUpdate(entityType: GalleryStateMO.self) { galleryStateMOs in
            galleryStateMOs.forEach { galleryStateMO in
                galleryStateMO.imageURLs = nil
                galleryStateMO.previewURLs = nil
                galleryStateMO.thumbnailURLs = nil
                galleryStateMO.originalImageURLs = nil
            }
        }
    }
    @MainActor func removeExpiredImageURLs() {
        fetchHistoryGalleries()
            .filter { Date().timeIntervalSince($0.lastOpenDate ?? .distantPast) > .oneWeek }
            .forEach { removeImageURLs(gid: $0.id) }
    }
    @MainActor func updateThumbnailURLs(gid: String, thumbnailURLs: [Int: URL]) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.thumbnailURLs, new: thumbnailURLs)
        }
    }
    @MainActor func updateImageURLs(gid: String, imageURLs: [Int: URL], originalImageURLs: [Int: URL]) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.imageURLs, new: imageURLs)
            update(gid: gid, storedData: &galleryStateMO.originalImageURLs, new: originalImageURLs)
        }
    }
    @MainActor func updatePreviewURLs(gid: String, previewURLs: [Int: URL]) {
        guard gid.isValidGID else { return }
        updateGalleryState(gid: gid) { galleryStateMO in
            update(gid: gid, storedData: &galleryStateMO.previewURLs, new: previewURLs)
        }
    }
}

// MARK: UpdateAppEnv
extension DatabaseClient {
    @MainActor func updateAppEnv(key: String, value: Any?) {
        update(
            entityType: AppEnvMO.self, createIfNil: true,
            commitChanges: { $0.setValue(value, forKeyPath: key) }
        )
    }
    @MainActor func updateSetting(_ setting: Setting) {
        updateAppEnv(key: "setting", value: setting.toData())
    }
    @MainActor func updateFilter(_ filter: Filter, range: FilterRange) {
        let key: String
        switch range {
        case .search:
            key = "searchFilter"
        case .global:
            key = "globalFilter"
        case .watched:
            key = "watchedFilter"
        }
        updateAppEnv(key: key, value: filter.toData())
    }
    @MainActor func updateTagTranslator(_ tagTranslator: TagTranslator) {
        updateAppEnv(key: "tagTranslator", value: tagTranslator.toData())
    }
    @MainActor func updateUser(_ user: User) {
        updateAppEnv(key: "user", value: user.toData())
    }
    @MainActor func updateHistoryKeywords(_ keywords: [String]) {
        updateAppEnv(key: "historyKeywords", value: keywords.toData())
    }
    @MainActor func updateQuickSearchWords(_ words: [QuickSearchWord]) {
        updateAppEnv(key: "quickSearchWords", value: words.toData())
    }

    // Update User
    @MainActor func updateUserProperty(_ commitChanges: @escaping (inout User) -> Void) {
        var user = fetchAppEnv().user
        commitChanges(&user)
        updateUser(user)
    }
    @MainActor func updateGreeting(_ greeting: Greeting) {
        updateUserProperty { user in
            user.greeting = greeting
        }
    }
    @MainActor func updateGalleryFunds(galleryPoints: String, credits: String) {
        updateUserProperty { user in
            user.credits = credits
            user.galleryPoints = galleryPoints
        }
    }
}
