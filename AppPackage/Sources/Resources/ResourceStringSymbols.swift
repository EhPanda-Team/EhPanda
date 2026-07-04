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

        public static var downloadStoreInvalidFolderName: LocalizedStringResource {
            LocalizedStringResource(
                "download_store.invalid_folder_name",
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
