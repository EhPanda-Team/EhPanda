"""EhPanda's languages in its AltStore and SideStore sources, and AltStore's rules for picking one.

The language codes are the keys of `localizedSubtitles` and `localizedDescriptions`, the same codes
as the app's string catalog. Each entry's plain field (`subtitle`, `description` or
`localizedDescription`) holds the English text: it is what AltStore shows when no key matches the
device's languages, and the only text SideStore and AltStore before 2.2 read.

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


def check_source(source, every_language=True, versions_required=True):
    """Problems that would keep AltStore or SideStore from reading `source` as EhPanda intends."""
    problems = []

    def require(where, entry, fields):
        for field in fields:
            value = entry.get(field)
            if value is None or (isinstance(value, str) and not value.strip()):
                problems.append(f"{where}: no {field}")

    require("source", source, SOURCE_FIELDS)
    for plain in ["subtitle", "description"]:
        problems += check_localized("source", source, plain, every_language)
    apps = source.get("apps")
    if not isinstance(apps, list) or not apps:
        return problems + ["source: no apps"]
    for app in apps:
        where = f"app {app.get('bundleIdentifier')}"
        require(where, app, APP_FIELDS)
        if "marketplaceID" in app:
            problems.append(f"{where}: has a marketplaceID, which SideStore refuses")
        for plain in ["subtitle", "localizedDescription"]:
            problems += check_localized(where, app, plain, every_language)
        versions = app.get("versions", [])
        if versions_required and not versions:
            problems.append(f"{where}: no versions, which SideStore refuses")
        for version in versions:
            version_where = f"{where} {version.get('version')} ({version.get('buildVersion')})"
            require(version_where, version, VERSION_FIELDS)
            problems += check_localized(version_where, version, "localizedDescription", False)
    return problems
