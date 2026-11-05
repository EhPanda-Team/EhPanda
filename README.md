<h1 align="center">EhPanda</h1>

<h4 align="center">An unofficial E-Hentai app for iOS</h4>

<p align="center">
<img src="https://user-images.githubusercontent.com/31207151/105609404-0acbff00-5de4-11eb-9e88-f3c6e0ba9d44.png" width="400"></img>
</p>

<p align="center">
  <a href="/README.md">English</a>・
  <a href="/READMEs/README.de.md">Deutsch</a>・
  <a href="/READMEs/README.ko.md">한국어</a>・
  <a href="/READMEs/README.jpn.md">日本語</a>・
  <a href="/READMEs/README.cht.md">繁體中文</a>・
  <a href="/READMEs/README.chs.md">简体中文</a>
</p>

## Installation
1. Download the IPA file from [Releases](https://github.com/EhPanda-Team/EhPanda/releases).
2. Install it on your device with a tool like [AltStore](https://altstore.io).

<sub>Requires iOS / iPadOS 27.0 or later.</sub>

## Community
[![Twitter](https://img.shields.io/badge/Twitter-2CA5E0?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/ehpandaapp)
[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/BSBE9FCBTq)
[![Telegram](https://img.shields.io/badge/Telegram-858585?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/ehpanda)

## Disclaimer
All content in this app comes from E-Hentai and is uploaded by its users.

**You access E-Hentai content at your own risk.**

## Analytics
EhPanda sends anonymous analytics data to [TelemetryDeck](https://telemetrydeck.com) so its maintainers can see how many people use the app and which features matter. **You choose how much is shared when you first open the app, and you can change your choice at any time in Settings → General → Analytics. Nothing is sent before you choose.** There are three levels:

- **Minimal**: Sends only a signal that EhPanda is installed, and where you installed the app from.
- **Basic**: Everything in Minimal, plus how often the app is used, which screens and features you use, technical details such as device model and app version, and which kinds of errors occur.
- **Full**: Everything in Basic, plus your reading and download activity and your main settings.

At every level, the data never includes gallery identifiers, tokens or titles, any gallery or page URL, search keyword text, tag values, usernames, cookies or any other credential, or file paths.

At Minimal, EhPanda sends a single install signal, once per install. It carries where you installed the app from (such as the App Store, TestFlight, an alternative app marketplace or the web) and a random identifier created for this install, and nothing about your device. The TelemetryDeck SDK is never started.

At Basic, EhPanda sends the same install signal, starts the TelemetryDeck SDK, and adds:
- how often the app is used: the SDK's own session signals and counts, such as the date you first opened the app, how many sessions there have been, how many separate days you have used it, and how long sessions last;
- which screens and features you use: the tabs and home sections you open, the filter and quick-search panels, saved searches, tag taps (the tag's namespace, never its value), and searches as a shape (word count, whether tag syntax was used, keyword length, and roughly how many results came back) rather than as text;
- which kinds of errors occur, including failed logins and Cloudflare challenges;
- the standard technical details that the SDK attaches to every event on its own: the device model and architecture, screen size, scale and orientation, the operating system version, the app version and build number, whether it is a debug or simulator build, your language, region, text-layout direction and time zone, the date and time of day the event was sent, and your system appearance and accessibility settings (light or dark mode, text size, bold text, reduce motion, reduce transparency, invert colors, increase contrast, and differentiate without color).

At Full, EhPanda adds the galleries you open (as a category and a count of tags per namespace, never the gallery itself), reading sessions as bucketed page counts and durations, download outcomes such as completed or failed, and the current values of five app settings on every event: gallery site, login state, reading direction, dual-page mode, and tag translation.

At Basic and Full, events carry TelemetryDeck's built-in anonymous per-install identifier, hashed on the device before sending. The identifier is not tied to you, and it resets whenever iOS regenerates the device's vendor identifier, which happens when every app from the same developer is removed. TelemetryDeck retains no IP addresses. See the [TelemetryDeck privacy policy](https://telemetrydeck.com/privacy) for how the data is handled.

Official releases are built with analytics credentials, which the release workflow supplies from repository secrets, so they send what the level you chose allows. A build made without those credentials sends nothing at all, whatever level is chosen: contributor builds from source and forks have analytics disabled because the credentials are absent.
