# Tag database compatibility

Owner authorizes implementation and tests, not repository recreation/publication.
Preserve other sessions' changes and existing account/signing configuration.

1. Shared display fallback for empty translated names, preserving searchable keys.
2. Support location namespace in decoding, gallery handling and suggestions, with six localized labels.
3. Build tag detail from any available description, image or link, including link-only entries.
4. Guard suggestion highlighting against ranges from raw Markdown being applied to different display text;
   recognize full namespaces even when no abbreviation exists.
5. Extend Japanese artifact inventory with current upstream keys and empty untranslated values.
   Preserve sourced translations; do not invent descriptions, images or translations.
6. Test empty-name lookups, search and namespace handling, details, raw JSON/cache roundtrip,
   and deterministic database generation. Run focused simulator tests, build and strict lint.
7. Record results and limitations. Do not claim missing upstream content has been translated.
