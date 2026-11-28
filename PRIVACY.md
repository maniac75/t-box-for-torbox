# T-Box Privacy Policy

*Last updated: 2026-11-15 · [Versión en español](PRIVACY.es.md)*

T-Box is an unofficial, open-source TorBox client for iPhone. It has **no servers, no accounts of its own, no analytics, no ads and no tracking**. This policy explains exactly what data the app handles, where it goes and who can see it.

## Data T-Box handles

| Data | Why | Where it is stored | Who receives it |
|---|---|---|---|
| **Your TorBox API key** | To talk to the TorBox API on your behalf | Only on your iPhone, in the iOS **Keychain** (also in a keychain group shared with T-Box's own Share extension) | Only **TorBox** (`api.torbox.app`), in the `Authorization` header or as the `token` parameter TorBox requires to create download links |
| Your TorBox email, plan and expiry date | Shown in the Account tab | Memory only, while the app runs | Read from TorBox; not sent anywhere else |
| Your TorBox items (names, sizes, progress) and your referral code | To show your library and your referral link | Memory only | Read from TorBox; not sent anywhere else |
| Files you download | Because you asked to download them | Your iPhone: Files › On My iPhone › T-Box, or Photos if you choose | Nobody, unless you share them |
| App settings (notifications on/off, unzip after download, your ntfy topic if enabled), the IDs of items still in progress, and a count of completed downloads | To remember your preferences, notify you when an item is ready, and show the support card once | On your iPhone (app settings) | Nobody |
| Pages you visit in Safari, **only if you turn on the T-Box Safari extension** | To find magnets, .torrent links and files from TorBox-supported sites on the page | Read on your iPhone while the page is open; the extension only stores which sites you hid the button on and the list of supported sites | Nobody. Links reach T-Box only when **you** tap the T-Box button. The extension downloads TorBox's public list of supported sites from `api.torbox.app` once a day, with no API key or personal data |
| Diagnostics log (network errors, request paths, app version, iOS version, device model) | To help fix bugs | On your iPhone. **Your API key is redacted** | Nobody, unless **you** export it and send it (e.g. in a GitHub issue) |

T-Box **does not** collect or store passwords, payment data, contacts, location, or any data from other apps.

## Third parties

- **TorBox** receives every API request, as with any TorBox client. See [TorBox's privacy policy](https://torbox.app/privacy).
- **ntfy.sh** (optional, off by default): if you turn on *Instant alerts with ntfy*, T-Box configures your TorBox account's webhook to a random ntfy topic. TorBox then sends notifications (including item names) to `ntfy.sh`. You can turn it off at any time in Account.
- **Infuse, VLC and other apps**: only if you choose *Open in…*, *Copy link* or *Share link*, T-Box hands that app a **temporary TorBox download link**. These links don't contain your API key.
- **GitHub (update check)**: at most every 12 hours, T-Box asks GitHub's public API which is the latest T-Box version, to show an update notice. It's an anonymous request with no account, API key or personal data; GitHub sees your IP address like any website does.
- **GitHub, Ko-fi**: the Feedback and Support links just open those websites in your browser. T-Box sends them nothing; the app and iOS version are only pre-filled in the bug-report form you see before submitting.

T-Box does not sell, rent or share your data with anyone else.

## Your control

- **Sign out** (Account) deletes your API key from the Keychain.
- Deleting the app removes all its local data, including downloaded files in its folder.
- *Copy API key* puts the key on the clipboard for 2 minutes only, and only when you confirm.

## Changes and contact

This policy may change as T-Box evolves; changes are listed in the [CHANGELOG](CHANGELOG.md). Questions: [open an issue](https://github.com/maniac75/t-box-for-torbox/issues) or a [discussion](https://github.com/maniac75/t-box-for-torbox/discussions). The source code is public, so you can verify everything described here.
