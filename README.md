<div align="center">

<img src="TBox/Assets.xcassets/AppIcon.appiconset/icon.png" width="120" alt="T-Box" />

# T-Box

**Unofficial [TorBox](https://torbox.app) client for iPhone.**
Native, fast, in English and Spanish. Built to be sideloaded.

[![Latest release](https://img.shields.io/github/v/release/maniac75/t-box-for-torbox?label=release)](https://github.com/maniac75/t-box-for-torbox/releases/latest)
[![Build](https://github.com/maniac75/t-box-for-torbox/actions/workflows/build.yml/badge.svg)](https://github.com/maniac75/t-box-for-torbox/actions/workflows/build.yml)
![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-orange?logo=swift)

**[⬇️ Download T-Box.ipa](https://github.com/maniac75/t-box-for-torbox/releases/latest/download/T-Box.ipa)** · [What's new](CHANGELOG.md) · [Supported sites](docs/SITES.md) · **[🇪🇸 Español](README.es.md)**

</div>

> T-Box is not affiliated with TorBox. "TorBox" is a trademark of its respective owners.

---

## What is it?

TorBox is a cloud service that downloads torrents, files from hosts like Mega or Mediafire, and videos from YouTube, Instagram or X, and hands them to you through a fast link. Its website works on iPhone, but it's clunky. **T-Box** is a native app that talks directly to the TorBox API: no middleman servers, no ads, no tracking.

## Screenshots

<p align="center">
  <img src="docs/screenshots/en-torrents.png" width="260" />
  <img src="docs/screenshots/en-web.png" width="260" />
  <img src="docs/screenshots/en-share-add.png" width="260" />
</p>
<p align="center">
  <img src="docs/screenshots/en-file-menu.png" width="260" />
  <img src="docs/screenshots/en-pdf.png" width="260" />
  <img src="docs/screenshots/en-account.png" width="260" />
</p>

*Torrents and web downloads with AirLock, sharing a YouTube link to T-Box, file actions, and the Account tab. All content shown is free or public domain.*

## Features

### Add
- **One place for everything**: paste magnets and web links mixed together, one per line. Each is recognized and goes to Torrents or Web.
- **`.torrent` files**, several at once, from Files or the Share sheet.
- **Live result** for each link (added, cached, queued, or error with its reason) and its progress in TorBox until it's ready.
- Tapping a **magnet in Safari** opens T-Box directly.
- **"Only if cached"** option, so you don't spend slots on downloads from scratch.
- **Supported site detection** when you paste a link, with a warning if the site is down. Fixes some problematic links automatically (Scribd).

### Library
- **Torrents** and **web downloads** with status, progress, speed and time left. Refreshes itself while something is in progress.
- Floating **activity bar** with what's downloading in TorBox and to the iPhone. Delete stalled items or cancel downloads from there.
- Search, filter (all, active, ready), delete and reannounce.
- **AirLock** (paid plans): keep items out of TorBox's 30-day inactivity cleanup, with a 🔒 on protected items.

### Files
- **Play** MP4/MOV with Picture in Picture and AirPlay. **Open in Infuse, VLC or VidHub** for MKV and other formats.
- **Preview** PDFs, images, documents and audio without saving them.
- **Download to iPhone** in the background, even if you close the app, to **Files › On My iPhone › T-Box**.
- **Save photos and videos straight to Photos**, e.g. from Instagram or X.
- **Download everything as .zip** and **unzip** automatically or on demand.
- Copy or share the temporary link (it doesn't expose your API key).

### Share
- **T-Box in the Share sheet** of any app: send magnets and links to TorBox from wherever you are. [Details](#share-from-other-apps)

### Notifications
- In-app alert when something finishes.
- **Notifications** when a download to iPhone finishes or something is ready in TorBox. **Test notification** button in Account.
- Optional: **instant alerts with [ntfy](https://ntfy.sh)** (experimental), set up with one tap.

## What works on each TorBox plan

| | Free | Essential / Standard | Pro |
|---|:-:|:-:|:-:|
| Torrents, library, downloads to iPhone, play and preview | ✅ | ✅ | ✅ |
| Web downloads (YouTube, Instagram, Mega…) | — | ✅ | ✅ |
| Usenet, TorBox streaming, RSS *(coming to T-Box)* | — | — | ✅ |

No account yet? **[Create one with the author's referral code](https://torbox.app/subscription?referral=7b4a584a-00a5-430e-aa31-809aa4934cb0)**. According to TorBox, when you buy a paid plan you both get 7 extra days for each month purchased.

## Install

1. Download **[T-Box.ipa](https://github.com/maniac75/t-box-for-torbox/releases/latest/download/T-Box.ipa)** on your iPhone.
2. Sign and install it with your sideloading method:
   - **Your own certificate**: Feather, ESign, KSign or another signing app.
   - **Free Apple ID**: SideStore or AltStore. The signature expires every 7 days and renews itself.
   - **Or add the T-Box source** to Feather, ESign, SideStore or AltStore to install it and get update notices right there:
     ```
     https://raw.githubusercontent.com/maniac75/t-box-for-torbox/main/docs/source.json
     ```
3. Open T-Box and tap **Get access code**: approve it on torbox.app and the app receives your API key by itself. You can also paste the key manually.

New versions appear in [Releases](https://github.com/maniac75/t-box-for-torbox/releases) with their changes. Each one includes `T-Box-X.Y.Z.ipa` (version in the name) and `T-Box.ipa` (same file, fixed name, for the direct download button). Versions marked **Pre-release** are test builds.

## Share from other apps

**T-Box appears in the Share sheet** of Safari, Instagram, YouTube, X, Scribd and any app that shares links. Tapping it **opens T-Box with the Add sheet already filled in**: check what was detected and tap **Add**, like sharing to WhatsApp.

If T-Box doesn't appear in the Share sheet, your signing app removed the extension: make sure **"Remove PlugIns / Remove extensions"** is off and sign again, or use the Shortcut below.

- The first time, T-Box may not be among the main icons: scroll the row to **More** and enable it.
- With SideStore/AltStore and a free Apple ID, the extension uses one more of the 10 weekly app IDs Apple allows.

### Alternative: Shortcut

If the extension doesn't work for you, an iOS Shortcut does the same:

1. Shortcuts › new shortcut › turn on **Show in Share Sheet**, receiving **URLs** and **Text**.
2. **URL Encode** action on the shortcut input.
3. **Open URLs** action: `tbox://add?text=` followed by the encoded result.

## Found a bug or have an idea?

- 🐞 **[Report a bug](https://github.com/maniac75/t-box-for-torbox/issues/new?template=bug_report.yml)**. Attach the diagnostics from Account › Export diagnostics: the API key is redacted automatically.
- 💡 **[Suggest an improvement](https://github.com/maniac75/t-box-for-torbox/issues/new?template=feature_request.yml)**
- 💬 **[Questions and conversation](https://github.com/maniac75/t-box-for-torbox/discussions)**

You can also do it from the app: Account › Feedback. Writing in English or Spanish is fine.

## Support the project

T-Box is free and always will be. If it's useful to you and you'd like to support it:

- ☕ [Buy me a coffee on Ko-fi](https://ko-fi.com/supermaniac) (card or PayPal, no account needed)
- ♥ [Sponsor on GitHub](https://github.com/sponsors/maniac75)
- 🎁 [Create or upgrade your TorBox account with the referral code](https://torbox.app/subscription?referral=7b4a584a-00a5-430e-aa31-809aa4934cb0): it costs you nothing and you both get extra days.

## About

T-Box is designed, tested and maintained by [maniac75](https://github.com/maniac75). The code is written with the help of Claude (AI); every feature is decided, reviewed and tested on a real iPhone before release.

## Privacy

Full details in the **[Privacy Policy](PRIVACY.md)**.


- The API key is stored in the **iPhone keychain** and is only sent to `api.torbox.app`.
- No analytics, no ads, no servers of our own.
- Links you share with other apps are temporary and don't contain your key.
- The exportable diagnostics (Account › Export diagnostics) **redact the API key** automatically.

## FAQ

**Why won't an MKV play inside the app?**
The iOS player doesn't open MKV. Use **Open in Infuse**, **Open in VLC** or **Open in VidHub** with the corresponding player installed. A built-in MKV player is on the roadmap.

**Where are my downloads?**
In the Files app › On My iPhone › T-Box. To move a file to iCloud or another folder, swipe it in "On iPhone" › Save to… › Save to Files.

**TorBox notifications arrive late when the app is closed.**
iOS decides when an app can check in the background: sometimes every 15 minutes, sometimes every few hours. For instant alerts, turn on **ntfy** in Account.

**I re-signed the app and it asks me to sign in again.**
That's normal if you changed certificates: the keychain is tied to whoever signed the app.

**Can I use it with another account or build my own version?**
Yes. The referral code and links are in [`TBox/Config.swift`](TBox/Config.swift).

## Roadmap

- [x] Unified library with queue, sorting, filters and multi-select (0.4.0)
- [x] Faster multi-part downloads, Live Activities, speed and time left (0.4.0)
- [ ] Usenet and clean titles in the library
- [ ] "iphone" tag with auto-download and download controls (Wi-Fi only, limit, pause)
- [ ] Home Screen widget and Siri shortcuts
- [ ] Watch: catalog with AIOStreams/Torrentio sources, MKV player (including watching while it downloads) and TorBox streaming (Pro)
- [ ] TorBox status, account stats and RSS (Pro)

## Build

Each change to `main` is built and tested on GitHub Actions and published as a pre-release. Stable versions are promoted manually. Release notes come from [CHANGELOG.md](CHANGELOG.md).

On a Mac:

```
brew install xcodegen
xcodegen generate
open TBox.xcodeproj
```

The [supported sites](docs/SITES.md) list updates itself weekly from the TorBox API.
