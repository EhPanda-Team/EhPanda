// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum L10n {
  public enum Constant {
    /// Constant.strings
    ///   EhPanda
    public static let galleryUnavailable = L10n.tr("Constant", "gallery_unavailable", fallback: "This gallery has been removed or is unavailable.")
  }
  public enum Localizable {
    /// Login
    public static let notLoginViewlogin = L10n.tr("Localizable", "not_login_viewlogin", fallback: "Login")
    public enum AccountSettingView {
      /// Login
      public static let login = L10n.tr("Localizable", "account_setting_view.login", fallback: "Login")
    }
    public enum Common {
      /// Cancel
      public static let cancel = L10n.tr("Localizable", "common.cancel", fallback: "Cancel")
      /// %@ day
      public static func day(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.day", String(describing: p1), fallback: "%@ day")
      }
      /// %@ days
      public static func days(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.days", String(describing: p1), fallback: "%@ days")
      }
      /// %@ hour
      public static func hour(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.hour", String(describing: p1), fallback: "%@ hour")
      }
      /// %@ hours
      public static func hours(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.hours", String(describing: p1), fallback: "%@ hours")
      }
      /// %@ minute
      public static func minute(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.minute", String(describing: p1), fallback: "%@ minute")
      }
      /// %@ minutes
      public static func minutes(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.minutes", String(describing: p1), fallback: "%@ minutes")
      }
      /// %@ pages
      public static func pages(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.pages", String(describing: p1), fallback: "%@ pages")
      }
      /// %@ second
      public static func second(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.second", String(describing: p1), fallback: "%@ second")
      }
      /// %@ seconds
      public static func seconds(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.seconds", String(describing: p1), fallback: "%@ seconds")
      }
      /// %@ stars
      public static func stars(_ p1: Any) -> String {
        return L10n.tr("Localizable", "common.stars", String(describing: p1), fallback: "%@ stars")
      }
    }
    public enum ConfirmationDialog {
      /// Clear
      public static let clear = L10n.tr("Localizable", "confirmation_dialog.clear", fallback: "Clear")
      /// Are you sure to clear?
      public static let clearDescription = L10n.tr("Localizable", "confirmation_dialog.clear_description", fallback: "Are you sure to clear?")
      /// Delete
      public static let delete = L10n.tr("Localizable", "confirmation_dialog.delete", fallback: "Delete")
      /// Are you sure to delete this item?
      public static let deleteDescription = L10n.tr("Localizable", "confirmation_dialog.delete_description", fallback: "Are you sure to delete this item?")
    }
    public enum DateSeekView {
      /// Seek to date
      public static let dateSeek = L10n.tr("Localizable", "date_seek_view.date_seek", fallback: "Seek to date")
    }
    public enum DetailView {
      /// Delete Download?
      public static let deleteDownload = L10n.tr("Localizable", "detail_view.delete_download", fallback: "Delete Download?")
      /// This will remove the downloaded gallery from this device.
      public static let deleteDownloadedGallery = L10n.tr("Localizable", "detail_view.delete_downloaded_gallery", fallback: "This will remove the downloaded gallery from this device.")
      /// Detail
      public static let detail = L10n.tr("Localizable", "detail_view.detail", fallback: "Detail")
      /// Language
      public static let language = L10n.tr("Localizable", "detail_view.language", fallback: "Language")
      /// Manage Folders
      public static let manageFolders = L10n.tr("Localizable", "detail_view.manage_folders", fallback: "Manage Folders")
      /// Share
      public static let share = L10n.tr("Localizable", "detail_view.share", fallback: "Share")
      /// Update
      public static let update = L10n.tr("Localizable", "detail_view.update", fallback: "Update")
    }
    public enum DownloadStore {
      /// The folder name is invalid.
      public static let invalidFolderName = L10n.tr("Localizable", "download_store.invalid_folder_name", fallback: "The folder name is invalid.")
      /// Manifest file is corrupted.
      public static let manifestCorrupted = L10n.tr("Localizable", "download_store.manifest_corrupted", fallback: "Manifest file is corrupted.")
      /// Page %d image data is corrupted.
      public static func pageImageCorrupted(_ p1: Int) -> String {
        return L10n.tr("Localizable", "download_store.page_image_corrupted", p1, fallback: "Page %d image data is corrupted.")
      }
      /// Page %d is missing.
      public static func pageMissing(_ p1: Int) -> String {
        return L10n.tr("Localizable", "download_store.page_missing", p1, fallback: "Page %d is missing.")
      }
    }
    public enum DownloadsView {
      /// Delete Download?
      public static let deleteDownload = L10n.tr("Localizable", "downloads_view.delete_download", fallback: "Delete Download?")
      /// This will remove the downloaded gallery from this device.
      public static let deleteDownloadedGallery = L10n.tr("Localizable", "downloads_view.delete_downloaded_gallery", fallback: "This will remove the downloaded gallery from this device.")
      /// Downloads
      public static let downloads = L10n.tr("Localizable", "downloads_view.downloads", fallback: "Downloads")
      /// Manage Folders
      public static let manageFolders = L10n.tr("Localizable", "downloads_view.manage_folders", fallback: "Manage Folders")
      /// Update
      public static let update = L10n.tr("Localizable", "downloads_view.update", fallback: "Update")
    }
    public enum ErrorView {
      /// Retry
      public static let retry = L10n.tr("Localizable", "error_view.retry", fallback: "Retry")
    }
    public enum FavoritesView {
      /// Favorites
      public static let favorites = L10n.tr("Localizable", "favorites_view.favorites", fallback: "Favorites")
    }
    public enum FiltersView {
      /// Filters
      public static let filters = L10n.tr("Localizable", "filters_view.filters", fallback: "Filters")
    }
    public enum GeneralSettingView {
      /// Language
      public static let language = L10n.tr("Localizable", "general_setting_view.language", fallback: "Language")
    }
    public enum HomeView {
      /// Home
      public static let home = L10n.tr("Localizable", "home_view.home", fallback: "Home")
    }
    public enum JumpPageView {
      /// Jump page
      public static let jumpPage = L10n.tr("Localizable", "jump_page_view.jump_page", fallback: "Jump page")
    }
    public enum LoginView {
      /// Login
      public static let login = L10n.tr("Localizable", "login_view.login", fallback: "Login")
    }
    public enum QuickSearchView {
      /// Quick search
      public static let quickSearch = L10n.tr("Localizable", "quick_search_view.quick_search", fallback: "Quick search")
    }
    public enum ReadingView {
      /// Share
      public static let share = L10n.tr("Localizable", "reading_view.share", fallback: "Share")
    }
    public enum SearchView {
      /// Quick search
      public static let quickSearch = L10n.tr("Localizable", "search_view.quick_search", fallback: "Quick search")
      /// Search
      public static let search = L10n.tr("Localizable", "search_view.search", fallback: "Search")
    }
    public enum SettingView {
      /// Setting
      public static let setting = L10n.tr("Localizable", "setting_view.setting", fallback: "Setting")
    }
    public enum TabItem {
      /// Downloads
      public static let downloads = L10n.tr("Localizable", "tab_item.downloads", fallback: "Downloads")
      /// Favorites
      public static let favorites = L10n.tr("Localizable", "tab_item.favorites", fallback: "Favorites")
      /// Home
      public static let home = L10n.tr("Localizable", "tab_item.home", fallback: "Home")
      /// Search
      public static let search = L10n.tr("Localizable", "tab_item.search", fallback: "Search")
      /// Setting
      public static let setting = L10n.tr("Localizable", "tab_item.setting", fallback: "Setting")
    }
    public enum ToolbarItem {
      /// Seek to date
      public static let dateSeek = L10n.tr("Localizable", "toolbar_item.date_seek", fallback: "Seek to date")
      /// Filters
      public static let filters = L10n.tr("Localizable", "toolbar_item.filters", fallback: "Filters")
      /// Jump page
      public static let jumpPage = L10n.tr("Localizable", "toolbar_item.jump_page", fallback: "Jump page")
      /// Quick search
      public static let quickSearch = L10n.tr("Localizable", "toolbar_item.quick_search", fallback: "Quick search")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
