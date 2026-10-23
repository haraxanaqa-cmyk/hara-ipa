# Dylib Lens — iOS shell

A thin, native **WKWebView** wrapper that turns the Dylib Lens web app into an
installable iPhone/iPad app.

- Live app it loads: **https://dylib-lens.web.zaka.live/**
- Deployment target: iOS 14.0+ (iPhone + iPad)
- Bundle id: `live.zaka.dyliblens` — change it in `project.yml` if you want your own.

## Why the shell loads a URL instead of bundling files

The scanner runs in a **Web Worker**. A `file://` bundle gives the worker an
opaque origin, so `new Worker(...)` fails and the scan dies on the first chunk.
Loading the hosted build over https keeps the worker alive, and the site's
service worker caches the whole UI after the first launch — so it still opens
offline. Selected files are read inside the web view and never uploaded.

## Get an .ipa

### Option A — GitHub Actions (no Mac needed, free)

1. Create a new repo on GitHub and upload this folder (drag & drop in the browser is fine).
2. The workflow in `.github/workflows/build-ipa.yml` runs automatically.
3. Open **Actions → Build IPA → the run → Artifacts → `DylibLens-ipa`**.
4. Unzip it: you get `DylibLens.ipa`.

Total time: about 3–5 minutes. The `.ipa` is unsigned — that is intentional.

### Option B — your own Mac

```bash
brew install xcodegen            # once
./build-ipa.sh                   # -> dist/DylibLens.ipa (unsigned)
TEAM_ID=ABCDE12345 ./build-ipa.sh  # optional: signed with your Apple developer team
```

`build-ipa.sh` generates the Xcode project, builds `Release` for `iphoneos`, and
packs `Payload/DylibLens.app` into `dist/DylibLens.ipa`.

## Install on the phone

- **Esign / Sideloadly / TrollStore** — import `DylibLens.ipa`, sign with your own
  certificate or Apple ID, install. Works on non-jailbroken devices.
- After install, iOS asks for a trust confirmation in
  *Settings → General → VPN & Device Management* if you used a free Apple ID.

## Skip the build entirely

You can have the exact same app without any signing:

Safari → open **https://dylib-lens.web.zaka.live/** → Share → **Add to Home Screen**.
It launches full-screen with its own icon, keeps working offline, and updates itself.

## Layout

```
project.yml                       XcodeGen spec (project file is generated)
Sources/AppDelegate.swift         entry point, single window
Sources/LensWebViewController.swift  WKWebView, progress bar, pull-to-refresh, offline retry
Support/Info.plist                bundle settings (orientation, launch screen, ATS)
Resources/Assets.xcassets         app icon (1024) + accent / launch colors
build-ipa.sh                      local build -> dist/DylibLens.ipa
.github/workflows/build-ipa.yml   CI build -> downloadable IPA artifact
```

## Changing the target

Edit one line in `Sources/LensWebViewController.swift`:

```swift
static let appURL = URL(string: "https://dylib-lens.web.zaka.live/")!
```

The navigation delegate treats that host as in-app and sends everything else to
Safari, so re-pointing the constant is enough.
