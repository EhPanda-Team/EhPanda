# Tag database compatibility

Empty translated names now display the original key while staying searchable. The `location` namespace
decodes, suggests and has labels in all six locales. Tag detail opens for any description, image or link,
and suggestion highlighting no longer applies raw Markdown ranges to rendered text.

## Verification

- Focused simulator run (TagTranslationFeature, FileClient, AppFeature, AppModels, DetailFeature): 293 of 294
  passed; the failure was the test's own assertion, because a highlight is itself a link containing `https://`.
  The assertion now checks that the raw image URL does not leak, and the 12 TagTranslationFeature tests pass.
- Strict lint is clean.

## Limitations

Missing upstream content has not been translated. Japanese coverage is limited to its sources: empty names show
the original English key. Not checked by eye in the running app.
