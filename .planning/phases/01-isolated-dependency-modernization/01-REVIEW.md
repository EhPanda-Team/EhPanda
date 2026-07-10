---
phase: 01-isolated-dependency-modernization
reviewed: 2026-07-10T04:17:49Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - AppPackage/Package.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/FileClient/FileClient.swift
  - AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift
  - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
  - AppPackage/Sources/MarkdownExt/MarkdownUtil.swift
  - AppPackage/Sources/NetworkingFeature/DFExtensions.swift
  - AppPackage/Sources/SwiftyOpenCC/ChineseConverter.swift
  - AppPackage/Sources/SwiftyOpenCC/ConversionDictionary.swift
  - AppPackage/Sources/SwiftyOpenCC/ConversionError.swift
  - AppPackage/Sources/SwiftyOpenCC/DictionaryLoader.swift
  - AppPackage/Sources/SwiftyOpenCC/DictionaryName.swift
  - AppPackage/Sources/SwiftyOpenCC/DictionaryStore.swift
  - AppPackage/Sources/TagTranslationFeature/TagTranslation+Markdown.swift
  - AppPackage/Sources/UIImageColors/UIImage+Colors.swift
  - AppPackage/Sources/UIImageColors/UIImageColors.swift
  - AppPackage/Sources/copencc/include/header.h
  - AppPackage/Sources/copencc/include/module.modulemap
  - AppPackage/Sources/copencc/source.cpp
  - AppPackage/Tests/FileClientTests/FileClientTests.swift
  - AppPackage/Tests/MarkdownExtTests/MarkdownUtilParityTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift
  - AppPackage/Tests/SwiftyOpenCCTests/ChineseConverterParityTests.swift
  - AppPackage/Tests/TagTranslationFeatureTests/TagTranslationMarkdownTests.swift
  - AppPackage/Tests/UIImageColorsTests/UIImageColorsParityTests.swift
findings:
  critical: 0
  warning: 5
  info: 3
  total: 8
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-07-10T04:17:49Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

Phase 1 replaces three external packages with app-owned local modules: `SwiftyOpenCC`
(over a vendored `copencc` C++ engine), `UIImageColors`, and `MarkdownExt` (over Apple
swift-markdown), plus dependency edits in `Package.swift` and import swaps in the two
feature files. The reimplementations are, on the whole, high quality and the parity intent
is genuinely reasoned:

- **ChineseConverter** correctly reproduces OpenCC's `s2t` / `s2hk` / `s2twp` pipelines
  (STPhrases segmentation, `[[STPhrases,STCharacters]]` base step, TWPhrases→TWVariants
  ordering for the Taiwan-idiom path). The parity test exercises real conversions with
  divergent regional output (`网络` → `網絡`/`網絡`/`網路`), which is a strong lock.
- **UIImageColors** faithfully replays the historical packed-`Double` color math,
  `with(minSaturation:)` HSV round-trip, `isDistinct`/`isContrasting`/`isDarkColor`
  thresholds, the black-or-white edge skip, and the device-scale, non-opaque
  rasterization. The overlapping `switch` bounds in `with(minSaturation:)` are safe
  (boundary values coincide). Explicit sRGB BGRA sampling is a correct hardening of the
  original's raw-buffer read.
- **MarkdownUtil** preserves the paragraph-only / top-level-`.text`-only traversal and the
  full-string `NSDataDetector` URL validation, both locked by tests.
- The known-deliberate items (retained `DeprecatedAPI` for domain fronting, upstream
  `ColorfulView` deprecation) were correctly excluded from findings. All four new modules
  carry a `parent_config` `.swiftlint.yml` per project convention.

No blockers. The findings below are concurrency/robustness gaps in the `copencc` C++ shim,
one fragile Swift idiom, and a parity-coverage weakness in the UIImageColors test suite.
Two Info items are pre-existing (not introduced this phase) but sit in reviewed files.

## Warnings

### WR-01: `ccErrorno` is a shared global, not thread-local — contradicts its own comment

**File:** `AppPackage/Sources/copencc/source.cpp:15`, `AppPackage/Sources/copencc/include/header.h:20-24`
**Issue:** `static CCErrorCode ccErrorno` is a process-global written by every `catch` in
`catchOpenCCException` and read by `CCLastErrorCode()`. Both the source comment ("on the
current thread") and the header comment ("recorded by the most recent bridge call on the
current thread… without tripping strict-concurrency's shared-mutable-state check") claim
per-thread semantics the code does not provide. `DictionaryStore`'s `Mutex` serializes
dictionary *loads* (so the paired load-then-`CCLastErrorCode()` read in
`ConversionDictionary.init` is safe against other loads), but *conversion* failures call
`catchOpenCCException` off that lock. A failing `convert(...)` on one thread can therefore
overwrite `ccErrorno` between another thread's (locked) failed load and its
`CCLastErrorCode()` read, yielding a misclassified `ConversionError` (e.g. `.unknown`
instead of `.invalidFormat`). It is also a formal data race on a non-atomic global. Impact
is bounded (non-fatal error misclassification under a rare double-failure race) but the
comment misrepresents the guarantee, and the whole point of moving to a function was
concurrency correctness.
**Fix:**
```cpp
// Give the variable the thread-local storage its comment promises.
static thread_local CCErrorCode ccErrorno = CCErrorCodeUnknown;
```

### WR-02: `CCDictDestroy` leaks the heap-allocated smart-pointer wrapper

**File:** `AppPackage/Sources/copencc/source.cpp:70-73` (with `52-58`, `60-68`)
**Issue:** `CCDictCreateMarisaWithPath` returns `new opencc::DictPtr(...)` and
`CCDictCreateWithGroup` returns `new opencc::DictGroupPtr(...)` — both heap-allocated
`shared_ptr` objects. `CCDictDestroy` calls `dictPtr->reset()`, which decrements the
managed dictionary's refcount but never `delete`s the wrapper object itself, leaking the
`shared_ptr` control-handle (~16 bytes) on every `ConversionDictionary.deinit`. Group
dictionaries (built fresh, uncached, per converter in `DictionaryLoader.conversionChain`)
are destroyed on every converter teardown, so `chtConverted` — invoked on each remote/
custom table build — leaks steadily over app lifetime. Secondary issue: `CCDictDestroy`
always `static_cast`s to `DictPtr*`, but group handles are `DictGroupPtr*`
(`shared_ptr<DictGroup>`); it works only because `shared_ptr` layout is type-independent
and the control block owns the real deleter — a latent type-erasure hazard.
**Fix:**
```cpp
void CCDictDestroy(CCDictRef _Nonnull dict) {
    // reset() only drops a reference; delete frees the shared_ptr wrapper itself.
    auto *dictPtr = static_cast<opencc::DictPtr*>(dict);
    delete dictPtr;
}
```
(Consider a single wrapper type, or a distinct destroy entry point, so the group cast is
not relied upon.)

### WR-03: `catchOpenCCException` lets `marisa::Exception` escape across the C/Swift boundary

**File:** `AppPackage/Sources/copencc/source.cpp:21-40` (load path `52-58`)
**Issue:** The catch chain only handles `opencc::` exception types. Loading a `.ocd2` whose
OpenCC header is valid but whose marisa trie body is truncated/corrupt reaches
`marisa::fread(...)` (`src/MarisaDict.cpp:105`), which throws a `marisa::Exception` via
`MARISA_THROW_IF` (`deps/marisa-0.2.6/lib/marisa/grimoire/io/reader.cc:129,134`).
`marisa::Exception` does **not** derive from `opencc::Exception`, so it is not caught,
propagates out of the Objective-C block through the `extern "C"` `CCDictCreateMarisaWithPath`
into `ConversionDictionary.init`, and — Swift cannot catch C++ exceptions — calls
`std::terminate()`. This defeats the module's stated contract ("conversion never crashes or
silently drops content") and turns a `ConversionError.invalidFormat` into a hard crash.
Likelihood is low (dictionaries are app-bundled and read-only), which is why this is a
Warning rather than a Blocker, but it is a genuine latent crash on corrupt bundle data.
**Fix:** Add a terminal catch-all so no exception crosses the boundary:
```cpp
    } catch (opencc::Exception& ex) {
        ccErrorno = CCErrorCodeUnknown;
        return NULL;
    } catch (...) {                       // marisa::Exception, std::exception, etc.
        ccErrorno = CCErrorCodeUnknown;
        return NULL;
    }
```

### WR-04: `chtConverted` mutates the dictionary while iterating it

**File:** `AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift:30-38`
**Issue:** `dictionary.forEach { key, value in dictionary[key] = ... }` iterates
`dictionary` while assigning into the same `var`. It produces the correct result only
because the key set is unchanged and copy-on-write splits the iterated buffer from the
mutated one on the first write — a fragile, non-obvious contract for a would-be maintainer
(any future edit that inserts/removes keys inside the loop becomes undefined). The
idiomatic, allocation-clean tool is `mapValues`.
**Fix:**
```swift
guard let converter = try? ChineseConverter(options: options) else { return self }
return mapValues { value in
    TagTranslation(
        namespace: value.namespace, key: value.key,
        value: customConversion(text: converter.convert(value.value)),
        description: value.description, linksString: value.linksString
    )
}
```

### WR-05: UIImageColors parity suite never exercises the accent-selection algorithm

**File:** `AppPackage/Tests/UIImageColorsTests/UIImageColorsParityTests.swift:60-84`
**Issue:** Both tests use solid *uniform gray* images. A uniform fill collapses to one
counted color, so only the background (edge color) and the black/white text fallback branch
are exercised — `proposed[1...3]` always take the fallback path. The most intricate,
regression-prone reimplemented code — `with(minSaturation:)`, `isDistinct`,
`isContrasting`, and the `accentColors` primary/secondary/detail selection loop — has **zero
coverage**. A parity divergence in accent selection (the code most likely to harbor a subtle
math bug) would pass this suite silently. The phase's core contract is behavior parity, so
the parity lock should cover the accent path, not just the trivial uniform case.
**Fix:** Add a deterministic multi-color fixture (e.g. a two-band image: dominant dark
background + a distinct saturated accent region) and assert the resulting
`primary`/`secondary`/`detail` component tuples against values captured from the external
package, keeping the small `isClose` tolerance. Grays alone cannot lock accent parity.

## Info

### IN-01: `HTTPBody()` defer deallocates the buffer before deinitializing it

**File:** `AppPackage/Sources/NetworkingFeature/DFExtensions.swift:120-124`
**Issue:** The `defer` calls `buffer.deallocate()` and then `buffer.deinitialize(count:)`,
so `deinitialize` touches already-freed memory. Harmless in practice (`UInt8` is trivial,
so `deinitialize` is a no-op), but the ordering is incorrect and misleading. Pre-existing —
this phase only added the DEP-06 comment above this block, not the buffer code.
**Fix:** Since the memory was written through a raw pointer and `UInt8` is trivial, drop the
`deinitialize` entirely and keep just `stream.close()` + `buffer.deallocate()`; if kept,
`deinitialize(count:)` must run before `deallocate()`.

### IN-02: `DictionaryStore` holds the `Mutex` across dictionary file I/O

**File:** `AppPackage/Sources/SwiftyOpenCC/DictionaryStore.swift:19-28`
**Issue:** `ConversionDictionary(path:)` (a file read / mmap into the C++ engine) runs
inside `cache.withLock`, serializing all first-time dictionary loads and blocking other
threads for the duration of I/O. Correct (it also dedupes concurrent loads of the same
path) and bounded given EhPanda's small fixed dictionary set; flagged only as a
lock-across-I/O smell. Performance is out of v1 review scope, so no change is required —
noted for awareness.

### IN-03: `int` loop counters against `intptr_t` count parameters

**File:** `AppPackage/Sources/copencc/source.cpp:62`, `:80`
**Issue:** `CCDictCreateWithGroup` and `CCConverterCreate` iterate `for (int i=0; i<count; …)`
where `count`/`chainCount` are `intptr_t`. A narrowing mismatch that is purely cosmetic here
(groups and chains hold at most a handful of dictionaries) but worth aligning the counter
type to the parameter (`intptr_t i` or `size_t`).

---

_Reviewed: 2026-07-10T04:17:49Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
