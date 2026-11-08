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
