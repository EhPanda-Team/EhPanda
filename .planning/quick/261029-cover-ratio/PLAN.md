# Shared book cover proportion and screenshot reselection

Owner request, 2026-10-29: use width:height 0.707:1 throughout gallery cover frames; remove screenshot galleries whose aspect-fill crop loses more than 10% of the source area, then acquire nonexplicit replacements to fill the vacant slots.

## Scope

1. One shared exact 0.707 cover constant for fixed-size covers, grid frames and cover placeholders. Preserve heights, text scaling, pixel rounding and fit/fill behavior. Page-preview and reader proportions are not covers and stay unchanged.
2. Compute `1 - min(sourceRatio / 0.707, 0.707 / sourceRatio)` using exact rational arithmetic. Reject strictly greater than 10%; retain the boundary. Remove rejected IDs from the active screenshot selection, including related flow/download/Live Text assignments. Preserve immutable earlier fixture versions and historical screenshots.
3. Fetch anonymous nonexplicit replacement metadata/covers and any scene-required page data. Review metadata and visible artwork; fill the original counts with distinct Home galleries. Export and validate a new fixture version; incomplete whole-book archives remain marked partial.
4. Run focused layout/artwork tests, build the app, inspect actual cover layouts, and record the new fixture and evidence. No release, push, baseline promotion, Phase 17 progress change or deferred runner exception.

Execution remains inline. Historical visual acceptance is not implied by this request.
