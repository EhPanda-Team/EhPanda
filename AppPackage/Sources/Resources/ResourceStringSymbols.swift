import Foundation

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private nonisolated let resourceStringSymbolsBundleDescription = LocalizedStringResource.BundleDescription
    .atURL(#bundle.bundleURL)

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public nonisolated extension LocalizedStringResource {
    enum RLocalizable {
        public static var cancel: LocalizedStringResource {
            LocalizedStringResource(
                "cancel",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var clear: LocalizedStringResource {
            LocalizedStringResource(
                "clear",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var clearDescription: LocalizedStringResource {
            LocalizedStringResource(
                "clear_description",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        /// The continued-download card's subtitle: three counts, no wording of its own.
        ///
        /// The parameter ORDER is load-bearing in a way the compiler cannot check. The catalog
        /// value is built from three *named* substitutions (`%#@completed@`, `%#@total@`,
        /// `%#@galleries@`) carrying `argNum` 1, 2 and 3, and a substitution resolves its argument
        /// positionally. `arguments` below is what supplies those positions, so reordering the three
        /// interpolations — or these three parameters, since they are passed straight through —
        /// silently renders pages where galleries belong, in all six locales and with no diagnostic.
        /// The labels are the only thing that makes the call site readable, which is why this symbol
        /// is a function with semantic labels rather than the positional shape a `%@` takes.
        ///
        /// Like every argument-taking symbol here, `arguments` carries no wording: the catalog owns
        /// the separators and the plural forms, and this literal exists only to bind the three
        /// integers to positions 1, 2 and 3.
        public static func continuedSessionSubtitle(
            completed: Int,
            total: Int,
            galleries: Int
        ) -> LocalizedStringResource {
            // Written inline rather than bound to a local. A standalone
            // `String.LocalizationValue` literal is itself an extractable string with no key
            // context, so Xcode harvested it into the catalog as a key named after its own format
            // — a stray `%lld%lld%lld` entry that reappeared on every build. Inline, the extractor
            // sees the key it belongs to and emits nothing extra.
            return LocalizedStringResource(
                "continued_session.subtitle",
                defaultValue:
                    "\(completed, specifier: "%lld")\(total, specifier: "%lld")\(galleries, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var continuedSessionTitle: LocalizedStringResource {
            LocalizedStringResource(
                "continued_session.title",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var dateSeek: LocalizedStringResource {
            LocalizedStringResource(
                "date_seek",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func days(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "days",
                defaultValue: "\(count, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var delete: LocalizedStringResource {
            LocalizedStringResource(
                "delete",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var deleteDescription: LocalizedStringResource {
            LocalizedStringResource(
                "delete_description",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var deleteDownload: LocalizedStringResource {
            LocalizedStringResource(
                "delete_download",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var deleteDownloadedGallery: LocalizedStringResource {
            LocalizedStringResource(
                "delete_downloaded_gallery",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var detail: LocalizedStringResource {
            LocalizedStringResource(
                "detail",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreDownloadBusy: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.download_busy",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreDownloadFolderMissing: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.download_folder_missing",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreFolderAlreadyExists: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.folder_already_exists",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreFolderBusyDownloading: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.folder_busy_downloading",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreInvalidFolderName: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.invalid_folder_name",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreInvalidPageSelection: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.invalid_page_selection",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreManifestCorrupted: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.manifest_corrupted",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStoreManifestMissing: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.manifest_missing",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func downloadStorePageImageCorrupted(page: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "download_store.page_image_corrupted",
                defaultValue: "\(page, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func downloadStorePageMissing(page: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "download_store.page_missing",
                defaultValue: "\(page, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloadStorePageSelectionOutdated: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.page_selection_outdated",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var downloads: LocalizedStringResource {
            LocalizedStringResource(
                "downloads",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var favorites: LocalizedStringResource {
            LocalizedStringResource(
                "favorites",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var filters: LocalizedStringResource {
            LocalizedStringResource(
                "filters",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var home: LocalizedStringResource {
            LocalizedStringResource(
                "home",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func hours(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "hours",
                defaultValue: "\(count, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var jumpPage: LocalizedStringResource {
            LocalizedStringResource(
                "jump_page",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var language: LocalizedStringResource {
            LocalizedStringResource(
                "language",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var login: LocalizedStringResource {
            LocalizedStringResource(
                "login",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var manageFolders: LocalizedStringResource {
            LocalizedStringResource(
                "manage_folders",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func minutes(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "minutes",
                defaultValue: "\(count, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func pages(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "pages",
                defaultValue: "\(count, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var quickSearch: LocalizedStringResource {
            LocalizedStringResource(
                "quick_search",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var retry: LocalizedStringResource {
            LocalizedStringResource(
                "retry",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var search: LocalizedStringResource {
            LocalizedStringResource(
                "search",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func seconds(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "seconds",
                defaultValue: "\(count, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var setting: LocalizedStringResource {
            LocalizedStringResource(
                "setting",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var share: LocalizedStringResource {
            LocalizedStringResource(
                "share",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func stars(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "stars",
                defaultValue: "\(count, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static var update: LocalizedStringResource {
            LocalizedStringResource(
                "update",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }
    }

    enum RConstant {
        public static var responseGalleryUnavailable: LocalizedStringResource {
            LocalizedStringResource(
                "response.gallery_unavailable",
                table: "Constant",
                bundle: resourceStringSymbolsBundleDescription
            )
        }
    }
}
