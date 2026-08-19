// Xcode generates one `internal` symbol per key for this module's two string catalogs
// (`Localizable.xcstrings`, `Constant.xcstrings`) under `STRING_CATALOG_GENERATE_SYMBOLS`, naming
// each after its key. This file is the module's public surface over those symbols, and it exists
// for exactly two reasons:
//
// 1. Access level. The generated members are `internal` and Swift offers no way to re-export them,
//    while every consumer reaches these strings from another module as `.RLocalizable.…` /
//    `.RConstant.…`.
// 2. Labels. A key whose value is a bare `%lld` generates a POSITIONAL signature
//    (`days(_ arg1: Int)`); this project's convention is a semantic label, so `days(count:)` and
//    its siblings are written out here and forward positionally.
//
// Every body forwards and hand-types nothing, so a key renamed, mistyped or deleted in a catalog is
// a compile error at its forwarder rather than a raw key name rendered on screen. That is why no
// runtime "does this key resolve" test exists for these keys: the compiler is the check. The
// dependency on generated symbols is not particular to this file either, since the project builds
// only through Xcode and every module-local catalog already resolves the same way.

import Foundation

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public nonisolated extension LocalizedStringResource {
    enum RLocalizable {
        public static var cancel: LocalizedStringResource { .cancel }

        public static var clear: LocalizedStringResource { .clear }

        public static var clearDescription: LocalizedStringResource { .clearDescription }

        /// The continued-download card's subtitle: three counts, no wording of its own.
        ///
        /// The catalog owns every separator and plural form, and the key accepts nothing but
        /// integers, so no content-identifying text has a path onto the card.
        ///
        /// Unlike the plural keys below, this symbol is labelled rather than positional because its
        /// catalog value is built from three *named* substitutions (`%#@completed@`, `%#@total@`,
        /// `%#@galleries@`): the generator derives the labels from those names, and this forwarder
        /// passes them straight through.
        public static func continuedSessionSubtitle(
            completed: Int,
            total: Int,
            galleries: Int
        ) -> LocalizedStringResource {
            .continuedSessionSubtitle(completed: completed, total: total, galleries: galleries)
        }

        public static var continuedSessionTitle: LocalizedStringResource { .continuedSessionTitle }

        public static var dateSeek: LocalizedStringResource { .dateSeek }

        public static func days(count: Int) -> LocalizedStringResource { .days(count) }

        public static var delete: LocalizedStringResource { .delete }

        public static var deleteDescription: LocalizedStringResource { .deleteDescription }

        public static var deleteDownload: LocalizedStringResource { .deleteDownload }

        public static var deleteDownloadedGallery: LocalizedStringResource { .deleteDownloadedGallery }

        public static var detail: LocalizedStringResource { .detail }

        public static var downloadStoreDownloadBusy: LocalizedStringResource { .downloadStoreDownloadBusy }

        public static var downloadStoreDownloadFolderMissing: LocalizedStringResource {
            .downloadStoreDownloadFolderMissing
        }

        public static var downloadStoreFolderAlreadyExists: LocalizedStringResource {
            .downloadStoreFolderAlreadyExists
        }

        public static var downloadStoreFolderBusyDownloading: LocalizedStringResource {
            .downloadStoreFolderBusyDownloading
        }

        public static var downloadStoreInvalidFolderName: LocalizedStringResource { .downloadStoreInvalidFolderName }

        public static var downloadStoreInvalidPageSelection: LocalizedStringResource {
            .downloadStoreInvalidPageSelection
        }

        public static var downloadStoreManifestCorrupted: LocalizedStringResource { .downloadStoreManifestCorrupted }

        public static var downloadStoreManifestMissing: LocalizedStringResource { .downloadStoreManifestMissing }

        public static func downloadStorePageImageCorrupted(page: Int) -> LocalizedStringResource {
            .downloadStorePageImageCorrupted(page)
        }

        public static func downloadStorePageMissing(page: Int) -> LocalizedStringResource {
            .downloadStorePageMissing(page)
        }

        public static var downloadStorePageSelectionOutdated: LocalizedStringResource {
            .downloadStorePageSelectionOutdated
        }

        public static var downloads: LocalizedStringResource { .downloads }

        public static var favorites: LocalizedStringResource { .favorites }

        public static var filters: LocalizedStringResource { .filters }

        public static var home: LocalizedStringResource { .home }

        public static func hours(count: Int) -> LocalizedStringResource { .hours(count) }

        public static var jumpPage: LocalizedStringResource { .jumpPage }

        public static var language: LocalizedStringResource { .language }

        public static var login: LocalizedStringResource { .login }

        public static var manageFolders: LocalizedStringResource { .manageFolders }

        public static func minutes(count: Int) -> LocalizedStringResource { .minutes(count) }

        public static func pages(count: Int) -> LocalizedStringResource { .pages(count) }

        public static var quickSearch: LocalizedStringResource { .quickSearch }

        public static var retry: LocalizedStringResource { .retry }

        public static var search: LocalizedStringResource { .search }

        public static func seconds(count: Int) -> LocalizedStringResource { .seconds(count) }

        public static var setting: LocalizedStringResource { .setting }

        public static var share: LocalizedStringResource { .share }

        public static func stars(count: Int) -> LocalizedStringResource { .stars(count) }

        public static var update: LocalizedStringResource { .update }
    }

    enum RConstant {
        public static var responseGalleryUnavailable: LocalizedStringResource { Constant.responseGalleryUnavailable }
    }
}
