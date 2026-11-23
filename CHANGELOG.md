# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions before 0.3.0 are pre-releases.

## [0.4.0] - Unreleased

### Added
- One Library tab for torrents and web downloads, with All / Torrents / Web.
- Filter (in progress, ready, favorites) and sort (newest, oldest, name, size). T-Box remembers your choice.
- Select several items to favorite, AirLock, download to iPhone or delete them in one go.
- Downloads to iPhone show live progress on the Lock Screen and in the Dynamic Island, with time left.
- Download speed and time left for each download to iPhone.
- Long-press an item for quick actions.

### Changed
- The Torrents and Web tabs are now a single Library tab.

## [0.3.3] - 2026-11-19

### Added
- Open in VidHub, alongside Infuse and VLC (thanks @goon-123).
- Update notice: Account shows when a new version is out.
- Retry button for failed downloads to iPhone.
- A note when your install can't download in the background.

## [0.3.2] - 2026-11-16

### Added
- Search by hash.

### Fixed
- Large libraries: all torrents and web downloads load, not only the first 1,000.
- Downloads to iPhone retry automatically when iOS can't create the file (some sideloaded setups).
- Search ignores accents ("pokemon" finds "Pokémon").
- New items sort correctly at the top.
- More detail in diagnostics for download errors.

## [0.3.1] - 2026-11-16

### Added
- Favorites: star a torrent or web download to keep it at the top.
- Privacy policy link in Account.

### Changed
- The search bar is always visible in Torrents and Web.

### Fixed
- The status label no longer splits into two lines.

## [0.3.0] - 2026-11-15

### Added
- AirLock: keep items from TorBox's 30-day cleanup (paid plans).
- Queue: see, start or delete queued downloads.
- Rename torrents and web downloads.
- Your referral code and link, ready to share.
- Copy your API key from Account.
- Feedback and Support sections in Account.

### Changed
- Share › T-Box opens the Add sheet directly.
- Downloads go to Files › On My iPhone › T-Box.
- Fewer false network-error messages.

## [0.2.3] - 2026-11-15

### Fixed
- Attempted fix for the folder picker (replaced in 0.3.0).

## [0.2.2] - 2026-11-15

### Added
- Delete stalled items and cancel all downloads from Activity.
- Clear the "Recently finished" list.

## [0.2.1] - 2026-11-15

### Added
- T-Box in the Share sheet of any app.
- Test notification button.
- Option to show 18+ supported sites.

## [0.2.0] - 2026-11-15

### Added
- One Add sheet for magnets, web links and .torrent files.
- Live status of each link, with Download and To Photos when ready.
- Activity bar with progress in TorBox and on the iPhone.
- Notifications when downloads finish or items are ready.
- Preview PDFs, images, documents and audio; unzip .zip files.
- Instant alerts with ntfy (experimental).

### Fixed
- Large .torrent files no longer fail.
- Scribd links now work.

## [0.1.1] - 2026-11-15

### Fixed
- Random "Operation cancelled" errors in the lists.

## [0.1.0] - 2026-11-15

### Added
- First version: sign in, torrent and web lists, add magnets and .torrent files, play videos or open in Infuse/VLC, background downloads to Files and Photos. English and Spanish.

[0.3.3]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.3.3
[0.3.2]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.3.2
[0.3.1]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.3.1
[0.3.0]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.3.0
[0.2.3]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.2.3
[0.2.2]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.2.2
[0.2.1]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.2.1
[0.2.0]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.2.0
[0.1.1]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.1.1
[0.1.0]: https://github.com/maniac75/t-box-for-torbox/releases/tag/v0.1.0
