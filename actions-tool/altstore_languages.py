"""EhPanda's languages in its AltStore and SideStore sources, and AltStore's rules for picking one.

The language codes are the keys of `localizedSubtitles` and `localizedDescriptions`, the same codes
as the app's string catalog. Each entry's plain field (`subtitle`, `description` or
`localizedDescription`) holds the English text: it is what AltStore shows when no key matches the
device's languages, and the only text SideStore and AltStore before 2.2 read.

`check_source` also checks the screenshots (owner msg 2628). AltStore and SideStore read
`screenshots` as a list (iPhone) or as an object with `iphone` and `ipad` lists, each item a URL or an
`{imageURL, width, height}` object; they decode `width` and `height` as Int16, so a fraction or a
value over 32767 breaks the source (AltStoreCore/Model/AppScreenshot.swift). EhPanda writes only the
object form, with the size in pixels.

`localized_value` is a copy of AltStore's `KeyedDecodingContainer.decodeLocalizedValue`
(AltStoreCore/Extensions/KeyedDecodingContainer+LocalizedValues.swift): the keys are lowercased; for
each of the device's preferred languages in order, the first exact match wins, and otherwise the
language is shortened one `-` component at a time. So a Taiwan device, whose first preferred
language reads `zh-Hant-TW`, finds `zh-Hant`. A key such as `zh-TW` would never match: iOS names the
script in the preferred language, and shortening `zh-hant-tw` gives `zh-hant` and `zh`, never `zh-tw`.
"""

# (code, the name shown to people), in the order the release notes file lists them.
LANGUAGES = [
    ("en", "English"),
    ("de", "Deutsch"),
    ("ja", "日本語"),
    ("ko", "한국어"),
    ("zh-Hans", "简体中文"),
    ("zh-Hant", "繁體中文"),
]
CODES = [code for code, _ in LANGUAGES]
DEFAULT = "en"


def localized_value(values, preferred_languages):
    """The value AltStore picks from `values` for a device with `preferred_languages`, or None."""
    lowered = {key.lower(): value for key, value in values.items()}
    for language in preferred_languages:
        language = language.lower()
        if language in lowered:
            return lowered[language]
        components = language.split("-")[:-1]
        while components:
            base = "-".join(components)
            if base in lowered:
                return lowered[base]
            components = components[:-1]
    return None


# The plain fields AltStore or SideStore need, which must also be non-empty. SideStore reads only these.
SOURCE_FIELDS = ["name", "identifier", "subtitle", "description", "iconURL"]
APP_FIELDS = ["name", "bundleIdentifier", "developerName", "subtitle", "localizedDescription", "iconURL"]
VERSION_FIELDS = ["version", "buildVersion", "date", "localizedDescription", "downloadURL", "size", "sha256"]
# An AltStore PAL entry points at an ADP (AltStore, "Make a Source"): `downloadURL` is the manifest's URL,
# `assetURLs` maps each ADP file name without its extension to its URL, `size` is one variant's, and there
# is no single IPA to hash, so no `sha256`.
PAL_VERSION_FIELDS = ["version", "buildVersion", "date", "localizedDescription", "downloadURL", "assetURLs", "size"]
# The icon and the screenshots that EhPanda serves from its assets repository: the path after this prefix is
# the file's path in a checkout of that repository.
ASSETS_URL = "https://raw.githubusercontent.com/EhPanda-Team/ehpanda-assets/main/"
SCREENSHOT_DEVICES = ["iphone", "ipad"]
INT16_MAX = 32767
# The localized object for each plain field, and whether it must list every language.
LOCALIZED = {"subtitle": "localizedSubtitles", "description": "localizedDescriptions",
             "localizedDescription": "localizedDescriptions"}


def check_localized(where, entry, plain, every_language):
    """Problems with `entry`'s localized object for its plain field `plain`."""
    key = LOCALIZED[plain]
    if key not in entry:
        return [f"{where}: no {key}"] if every_language else []
    values = entry[key]
    if not isinstance(values, dict) or not values:
        return [f"{where}: {key} is not a non-empty object"]
    problems = []
    lowered = [code.lower() for code in values]
    if len(set(lowered)) != len(lowered):
        problems.append(f"{where}: {key} lists a language twice, ignoring case")
    unknown = [code for code in values if code not in CODES]
    if unknown:
        problems.append(f"{where}: {key} has unknown languages {unknown}")
    if every_language and list(values) != CODES:
        problems.append(f"{where}: {key} lists {list(values)}, not {CODES}")
    if DEFAULT not in values:
        # Without it, a device preferring English over a listed language would get that language.
        problems.append(f"{where}: {key} has no {DEFAULT}")
    elif values[DEFAULT] != entry.get(plain):
        problems.append(f"{where}: {key}.{DEFAULT} differs from {plain}")
    problems += [f"{where}: {key}.{code} is empty" for code, value in values.items()
                 if not isinstance(value, str) or not value.strip()]
    return problems


def check_icon(where, entry, assets_dir=None):
    """Problems with `entry`'s iconURL: when `assets_dir`, a checkout of the assets repository, is given, an
    icon served from it must be a file there."""
    url = entry.get("iconURL")
    if assets_dir is None or not isinstance(url, str) or not url.startswith(ASSETS_URL):
        return []
    path = url[len(ASSETS_URL):]
    if (assets_dir / path).is_file():
        return []
    return [f"{where}: iconURL {path} is not in the assets repository"]


def check_screenshots(where, app, assets_dir=None):
    """Problems with `app`'s screenshots. When `assets_dir`, a checkout of the assets repository, is
    given, each screenshot served from it must be a file there."""
    if "screenshots" not in app:
        return []
    screenshots = app["screenshots"]
    if not isinstance(screenshots, dict) or not screenshots:
        return [f"{where}: screenshots is not an object with {SCREENSHOT_DEVICES} lists"]
    problems = []
    unknown = [device for device in screenshots if device not in SCREENSHOT_DEVICES]
    if unknown:
        problems.append(f"{where}: screenshots has unknown devices {unknown}")
    for device, items in screenshots.items():
        if not isinstance(items, list) or not items:
            problems.append(f"{where}: screenshots.{device} is not a non-empty list")
            continue
        urls = []
        for index, item in enumerate(items):
            item_where = f"{where}: screenshots.{device}[{index}]"
            if not isinstance(item, dict) or set(item) != {"imageURL", "width", "height"}:
                problems.append(f"{item_where} is not an object with exactly imageURL, width and height")
                continue
            url = item["imageURL"]
            if not isinstance(url, str) or not url.startswith("https://") or len(url) <= len("https://"):
                problems.append(f"{item_where}: imageURL {url!r} is not an https URL")
                continue
            urls.append(url)
            for dimension in ["width", "height"]:
                value = item[dimension]
                # bool is an int in Python, and a float such as 19.5 is not an Int16.
                if isinstance(value, bool) or not isinstance(value, int) or not 0 < value <= INT16_MAX:
                    problems.append(f"{item_where}: {dimension} {value!r} is not a whole number from 1 to {INT16_MAX}")
            if assets_dir is not None and url.startswith(ASSETS_URL):
                path = url[len(ASSETS_URL):]
                if not (assets_dir / path).is_file():
                    problems.append(f"{item_where}: {path} is not in the assets repository")
        if len(set(urls)) != len(urls):
            problems.append(f"{where}: screenshots.{device} lists an image twice")
    return problems


def https_url(value):
    return isinstance(value, str) and value.startswith("https://") and len(value) > len("https://")


def check_pal_version(where, version):
    """Problems with an AltStore PAL version entry (Research §4)."""
    problems = []
    if "sha256" in version:
        problems.append(f"{where}: has a sha256, which an ADP entry does not")
    size = version.get("size")
    if size is not None and (isinstance(size, bool) or not isinstance(size, int) or size <= 0):
        problems.append(f"{where}: size {size!r} is not a positive whole number")
    asset_urls = version.get("assetURLs")
    if asset_urls is None:
        return problems
    if not isinstance(asset_urls, dict) or not asset_urls:
        return problems + [f"{where}: assetURLs is not a non-empty object"]
    problems += [f"{where}: assetURLs.{key} is not an https URL" for key, url in asset_urls.items()
                 if not https_url(url)]
    if "manifest" not in asset_urls:
        problems.append(f"{where}: assetURLs has no manifest")
    elif version.get("downloadURL") is not None and version.get("downloadURL") != asset_urls["manifest"]:
        problems.append(f"{where}: downloadURL is not assetURLs.manifest")
    return problems


def check_source(source, every_language=True, versions_required=True, assets_dir=None, pal=False):
    """Problems that would keep AltStore or SideStore from reading `source` as EhPanda intends.

    `assets_dir` is a checkout of the assets repository (a `pathlib.Path`), or None to not look for the
    icon and the screenshots EhPanda serves from there. With `pal`, `source` is the AltStore PAL source: its
    app needs a numeric `marketplaceID` (SideStore refuses one, so only here), the source is marked `nsfw`,
    and each version is an ADP entry (`check_pal_version`) instead of a single IPA."""
    problems = []

    def require(where, entry, fields):
        for field in fields:
            value = entry.get(field)
            if value is None or (isinstance(value, str) and not value.strip()):
                problems.append(f"{where}: no {field}")

    require("source", source, SOURCE_FIELDS)
    problems += check_icon("source", source, assets_dir)
    if pal and source.get("nsfw") is not True:
        problems.append("source: nsfw is not true")
    for plain in ["subtitle", "description"]:
        problems += check_localized("source", source, plain, every_language)
    apps = source.get("apps")
    if not isinstance(apps, list) or not apps:
        return problems + ["source: no apps"]
    for app in apps:
        where = f"app {app.get('bundleIdentifier')}"
        require(where, app, APP_FIELDS)
        problems += check_icon(where, app, assets_dir)
        if pal:
            if "marketplaceID" not in app:
                problems.append(f"{where}: no marketplaceID")
            elif not isinstance(app["marketplaceID"], str) or not app["marketplaceID"].isascii() \
                    or not app["marketplaceID"].isdigit():
                problems.append(f"{where}: marketplaceID {app['marketplaceID']!r} is not the app's Apple ID (digits)")
        elif "marketplaceID" in app:
            problems.append(f"{where}: has a marketplaceID, which SideStore refuses")
        for plain in ["subtitle", "localizedDescription"]:
            problems += check_localized(where, app, plain, every_language)
        problems += check_screenshots(where, app, assets_dir)
        versions = app.get("versions", [])
        if versions_required and not versions:
            problems.append(f"{where}: no versions, which SideStore refuses")
        for version in versions:
            version_where = f"{where} {version.get('version')} ({version.get('buildVersion')})"
            require(version_where, version, PAL_VERSION_FIELDS if pal else VERSION_FIELDS)
            if pal:
                problems += check_pal_version(version_where, version)
            problems += check_localized(version_where, version, "localizedDescription", False)
    return problems
