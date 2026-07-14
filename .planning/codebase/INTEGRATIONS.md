# External Integrations

**Analysis Date:** 2026-07-09

## APIs & External Services

**E-Hentai / ExHentai (primary content source):**
- `https://e-hentai.org/` and `https://exhentai.org/` - Gallery listings, search, favorites, detail pages (scraped HTML, parsed with Kanna in `AppPackage/Sources/ParserFeature`)
- `https://api.e-hentai.org/api.php` - JSON API for gallery metadata, torrents, and MPV page tokens
- `https://e-hentai.org/archiver.php` - Archive download links
- `https://e-hentai.org/favorites.php` - User favorites management
- `https://e-hentai.org/fullimg.php`, `https://e-hentai.org/g/...` - Full-image and gallery page endpoints
- `https://e-hentai.org/exchange.php`, `bounty.php`, `bitcoin.php`, `bounce` - Ancillary E-Hentai endpoints
- Request layer: `AppPackage/Sources/NetworkingFeature` (URLSession-based; `URLSession` used ~81 times across sources)
- SDK/Client: none — raw `URLSession` + Kanna HTML parsing; no vendored API SDK
- Auth: session cookies (see Authentication section)

**Hath network (image CDN):**
- `*.hath.network` hosts (e.g. `akrtazd.spuqplybaxmf.hath.network`) - Serve gallery page images; loaded via Kingfisher / SDWebImage

**GitHub:**
- `https://api.github.com/repos/` - App update/version checks against the EhPanda-Team repo
- `https://raw.githubusercontent.com/...` - Fetches EhTagTranslation database for tag translation (`AppPackage/Sources/TagTranslationFeature`)

**EhTagTranslation:**
- External community tag-translation database (GitHub-hosted) - Downloaded and rebuilt into a local cache file; the `tagTranslator` model is a thin info record plus a rebuilt cache file (per persistence refactor)

## Data Storage

**Databases:**
- None. All Core Data was dropped in the persistence refactor (no migration path retained).
- Light app data persisted via swift-sharing `@Shared` (in-memory + UserDefaults-backed), NOT `fileStorage`

**File Storage:**
- Local filesystem via `AppPackage/Sources/FileClient` - Downloaded galleries, logs, and the rebuilt tag-translation cache file
- Downloads managed by `AppPackage/Sources/DownloadClient`

**Caching:**
- Kingfisher image cache (disk + memory) - primary image cache
- SDWebImage cache (`DataCache`) - animated images; consumers resolve the injectable
  `dataCache` dependency, whose live actor also receives system-purge events

## Authentication & Identity

**Auth Provider:**
- E-Hentai / ExHentai session cookies (no OAuth, no third-party identity provider)
- Implementation: `AppPackage/Sources/CookieClient/CookieClient.swift` manages `HTTPCookie`s (`ipb_member_id`, `ipb_pass_hash`, `igneous`, etc.) in the shared cookie storage
- Login performed via `WKWebView` (`WKWebView` referenced 5x) so the user authenticates on the E-Hentai web login and cookies are captured

## Monitoring & Observability

**Error Tracking:**
- None. No Sentry/Crashlytics/analytics SDK present.

**Logs:**
- OSLog via `AppPackage/Sources/OSLogExt` and `LogsClient` - structured app logging
- Activity/diagnostic logs written to disk through `FileClient`; viewable in the Setting screen

## CI/CD & Deployment

**Hosting:**
- Sideloaded distribution (AltStore); metadata in `AltStore.json`. Not App Store distributed.

**CI Pipeline:**
- GitHub Actions (`.github/` workflows present) plus `actions-tool/` helper and `.githooks/`

## Environment Configuration

**Required env vars:**
- None. No secrets baked into the app; all authenticated access uses user-supplied E-Hentai cookies obtained at runtime.

**Secrets location:**
- User session cookies live in system `HTTPCookieStorage` (managed by `CookieClient`); no bundled credentials

## Webhooks & Callbacks

**Incoming:**
- Custom URL scheme / deep links handled via `AppPackage/Sources/URLClient` (opening `e-hentai.org` gallery URLs into the app)
- Share Extension (`ShareExtension/`) - receives shared URLs from other apps

**Outgoing:**
- Background download processing task `app.ehpanda.downloads.processing` (`BGProcessingTask`, declared in `App/Info.plist`) scheduled via `BackgroundProcessingClient`
- Local user notifications (`UNUserNotification`) for download completion via `SystemNotificationExt`

---

*Integration audit: 2026-07-09*
