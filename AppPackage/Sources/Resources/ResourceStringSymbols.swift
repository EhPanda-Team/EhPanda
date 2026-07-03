import Foundation

#if SWIFT_PACKAGE
private nonisolated let resourceStringSymbolsBundle = Foundation.Bundle.module
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private nonisolated let resourceStringSymbolsBundleDescription = LocalizedStringResource.BundleDescription
    .atURL(resourceStringSymbolsBundle.bundleURL)
#else
private final class ResourceStringSymbolsBundleClass {}
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private nonisolated let resourceStringSymbolsBundleDescription = LocalizedStringResource.BundleDescription
    .forClass(ResourceStringSymbolsBundleClass.self)
#endif

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

        public static func days(_ arg1: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "days",
                defaultValue: "\(arg1, specifier: "%lld")",
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

        public static func downloadStorePageImageCorrupted(_ arg1: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "download_store.page_image_corrupted",
                defaultValue: "\(arg1, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func downloadStorePageMissing(_ arg1: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "download_store.page_missing",
                defaultValue: "\(arg1, specifier: "%lld")",
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

        public static func hours(_ arg1: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "hours",
                defaultValue: "\(arg1, specifier: "%lld")",
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

        public static func minutes(_ arg1: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "minutes",
                defaultValue: "\(arg1, specifier: "%lld")",
                table: "Localizable",
                bundle: resourceStringSymbolsBundleDescription
            )
        }

        public static func pages(_ arg1: String) -> LocalizedStringResource {
            LocalizedStringResource(
                "pages",
                defaultValue: "\(arg1)",
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

        public static func seconds(_ arg1: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "seconds",
                defaultValue: "\(arg1, specifier: "%lld")",
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

        public static func stars(_ arg1: String) -> LocalizedStringResource {
            LocalizedStringResource(
                "stars",
                defaultValue: "\(arg1)",
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
