# Play WoW on Mobile

**An Android companion launcher and game-folder toolkit for World of Warcraft: Wrath of the Lich King (3.3.5a).**

Play WoW on Mobile is a community-oriented Flutter project. It helps players organize a locally stored WoW client, inspect selected game files, save realm connection profiles, and compare MPQ file fingerprints. It is a launcher/helper prototype — **it does not currently bundle the Windows WoW game client or a compatibility runtime, and it does not yet prove that the game can be played directly on Android.**

> **Status:** Experimental / in development. Builds and automated tests are useful checks, but real-device storage, realm, and game-runtime compatibility still require testing on supported Android devices.

## 🧭 Contents

- [Project goals](#project-goals)
- [What it does](#what-it-does)
- [What it does not do yet](#what-it-does-not-do-yet)
- [Requirements](#requirements)
- [Install and build](#install-and-build)
- [First-time setup](#first-time-setup)
- [Feature guide](#feature-guide)
- [Android storage access](#android-storage-access)
- [MPQ checks and SHA-256](#mpq-checks-and-sha-256)
- [Realm connection diagnostics](#realm-connection-diagnostics)
- [Data, privacy, and safety](#data-privacy-and-safety)
- [Troubleshooting](#troubleshooting)
- [Development and tests](#development-and-tests)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Project limitations and disclaimer](#project-limitations-and-disclaimer)

## 🎯 Project goals

The project aims to make managing a WotLK 3.3.5a client on Android easier, especially for users who keep a game folder on device storage. Its current focus is file access, inspection, realm profile management, and diagnostics. A future mobile game runtime is a separate engineering task and is not implied by the launcher UI.

## 🧰 Features

| Feature | Current purpose |
|---|---|
| WOW LK launcher interface | Dark, gold-accented fantasy-themed Flutter interface with GAME, REALMS, and OPTIONS navigation |
| Game folder selection | Uses Android's system document-tree picker to grant access to a selected game folder |
| Game Folder Inspector | Checks for a root-level `Wow.exe` / `Wow-64.exe`, `Data/`, locale directories, realmlist files, and MPQ archives where the Android document provider exposes them |
| Realmlist manager | Stores named realm profiles and can write a selected profile to a detected `Data/<locale>/realmlist.wtf` through Android document access |
| Realm profile backup | Imports and exports versioned JSON backups of saved realm profiles |
| DNS diagnostic | Resolves the saved realm hostname using the device's network resolver |
| TCP diagnostic | Checks whether the configured host and port accept a TCP connection; this is not a WoW login test |
| MPQ SHA-256 scanner | On filesystem-accessible folders, streams MPQ files and calculates SHA-256 fingerprints |
| Checksum baseline library | Saves named, user-created local snapshots and compares later fingerprints; JSON import/export is supported in the filesystem scanner flow |
| MPQ scan history | Keeps recent scan summaries and limited detailed fingerprint history locally, with scan-to-scan comparison |
| Graphics configuration | Saves Auto, Low, Low–Medium, Medium, and High starting presets; recommendations are based on detected device information and are not applied to the Windows game runtime |\n| Device diagnostics | Shows detected hardware and graphics details, allows a device rescan, and copies a diagnostic report to the clipboard |\n| Touch controls preference | Saves the touch-control overlay preference in local app settings |

Features depend on Android version, device, and the storage provider used to select the folder. See [Android storage access](#android-storage-access) and [What it does not do yet](#what-it-does-not-do-yet).

## 🚧 What it does not do yet

Please read this before installing or reporting a bug:

- It does not include Blizzard's WoW client files.
- It does not currently include Wine, Box64, Winlator, or another Windows compatibility layer.
- It does not currently demonstrate that `Wow.exe` can be launched and played on Android.
- It does not patch, repair, download, or authenticate a WoW installation.
- It does not guarantee that a saved realm supports the exact 3.3.5a client.
- A successful DNS or TCP check does not mean WoW authentication or gameplay will work.
- The Android document-tree scanner currently provides structural inventory. The SHA-256 scanner and manifest/history UI use normal filesystem paths; full document-provider streaming hash support is not yet implemented.
- PE executable version inspection is not currently available through the Android document-tree scan path.
- The app has not been validated against every Android OEM, Android release, or file manager/document provider.

## 📋 Requirements

### For users

- An Android phone or tablet.
- A locally stored WoW 3.3.5a client folder, if you want to use the folder inspection and realm tools.
- Permission to access that folder using Android's system folder picker.
- A valid realm hostname and port supplied by the server administrator, if using the connection diagnostics.

### For developers

- Flutter stable (the CI workflow currently pins Flutter 3.35.7).
- A compatible Android SDK and Java 17 toolchain.
- Git and a GitHub account if you want to build from this repository.

## 🚀 Install and build

### Install a release or test APK

1. Download the APK from the repository's latest successful GitHub Actions artifact or release, when one is published.
2. Install it on an Android device.
3. Open **Play WoW on Mobile / WOW LK**.
4. Grant access to the game folder using the in-app folder selection button and Android's system picker.

A workflow run is not a release. Only use an APK artifact after the workflow has completed successfully and the artifact is available. Do not install an APK from a failed or incomplete run.

### Build from source

Clone the repository and run:

```bash
git clone https://github.com/madu011/play-wow-on-mobile.git
cd play-wow-on-mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The generated release APK is normally at:

```
build/app/outputs/flutter-apk/app-release.apk
```

The repository name may change; update the clone URL and folder name if it has been renamed.

## 🧙 First-time setup

1. Open the app.
2. Tap **SELECT WOW GAME FOLDER**.
3. In Android's system folder picker, navigate to the actual top-level game directory — the directory that contains `Wow.exe` (or `Wow-64.exe`) and `Data/`.
4. Confirm **Use this folder / Allow** in Android's picker.
5. Review the Game Folder Inspector results.
6. Open REALMS and add the realm hostname/realmlist line provided by the server operator.
7. Select the saved profile to make it active.
8. If Android access is granted and the expected locale folder is present, the app can attempt to update `Data/<locale>/realmlist.wtf`.

Do not select only the `Data/` folder if the app asks for the top-level game folder.

## 🗺️ Feature guide

### GAME — folder selection and inspection

The folder inspector checks for:

- The selected folder.
- A root-level `Wow.exe` or `Wow-64.exe`.
- The `Data/` directory.
- Locale folders such as `enUS` and `enGB`.
- `realmlist.wtf` files under locale folders.
- Files ending in `.mpq`, their visible sizes, zero-byte files, and common archive names.

The scan is a structural inventory only. A missing common archive name is a warning to investigate against the exact client distribution, not proof that the installation is broken. Some repacks and distributions use different file layouts and names.

### REALMS — saved server profiles

The Server Manager supports named realm profiles. A profile can contain a display name and a realmlist host/port. Use the exact connection information supplied by the server operator.

Examples of accepted input formats:

```text
logon.example.net
SET realmlist "logon.example.net"
logon.example.net:3724
```

The example hostname is illustrative only; it is not a real server recommendation. If a server uses a non-standard authentication port, use the port supplied by that server.

Realm profiles can be exported to a versioned JSON backup and imported on another device. Imported data is validated, and duplicate host-and-port entries are skipped.

### Realm connection diagnostics

The connection test separates:

1. **DNS lookup:** whether the device can resolve the configured hostname.
2. **TCP reachability:** whether the configured address and port accept a TCP connection at test time.

A TCP connection is not the same as a successful WoW login. Authentication, realm selection, world-server routing, client build, and gameplay compatibility are separate checks.

### OPTIONS — local preferences

The current launcher includes saved graphics presets (Auto, Low, Low–Medium, Medium, and High), automatic device-based starting recommendations, a touch-control preference, and a device diagnostics report that can be copied to the clipboard. These are launcher-side preferences and recommendations only; they are not applied to the Windows game and do not install a graphics driver or make the Windows client run on Android.

## 📂 Android storage access

Modern Android versions restrict broad filesystem access. Selecting a directory in one picker does not necessarily give an app unrestricted access through ordinary `/storage/emulated/0/...` paths.

This project uses Android's Storage Access Framework (SAF) document-tree permission for the game-folder selection, structural scan, and realmlist write path. Choose the top-level game folder and approve the system permission prompt.

If the inspector shows zero MPQ files or cannot find the executable:

- Confirm you selected the actual game root, not Downloads or only the Data directory.
- Confirm the selected folder visibly contains the expected files in Android's file picker.
- Try reselecting the folder and granting access again.
- Some document providers expose incomplete metadata or restrict child enumeration. Results may vary by device and provider.

**Current limitation:** the SAF path does not yet provide the same streaming SHA-256 scanner and baseline workflow as the ordinary filesystem path. Do not treat an SAF scan showing zero files as proof that the game folder is empty.

## 🔍 MPQ checks and SHA-256

Where ordinary filesystem access is available, the scanner reads MPQ archives as a stream and calculates SHA-256 fingerprints without loading the entire archive into memory.

A fingerprint identifies the exact bytes read. It does not decide whether those bytes are official or correct. To make an integrity judgement, compare the hash with a trusted checksum for the exact same client distribution.

The baseline library stores user-created snapshots. A baseline created from a modified or incomplete client is still only a snapshot; it is not an official Blizzard checksum database. The scan history stores summary metadata and, for a limited number of recent scans, per-file fingerprints. It does not store MPQ archive contents.

## 🔐 Data, privacy, and safety

- Realm profiles and scan history are intended to be stored locally on the device.
- Realm JSON backups contain saved server addresses and profile names; keep them private if you do not want to share those details.
- Do not enter or store your WoW account password in this launcher.
- The app does not need your WoW account password for the current folder inspection and realm profile features.
- Do not download copyrighted game data from unofficial sources. Use game files you are legally entitled to use.
- Never treat a server address, checksum, or executable marker from an unknown source as trusted.

Review the source code and Android permissions before installing community builds.

## 🛠️ Troubleshooting

| Problem | What to check |
|---|---|
| Permission denied while writing realmlist | Reselect the top-level game folder with Android's system folder picker and approve access. Do not rely only on Android's general Files permission toggle. |
| Inspector says Wow.exe not found | Select the directory that directly contains Wow.exe / Wow-64.exe. |
| Data folder found but no MPQ files | Check the actual Data contents and whether the selected document provider exposes nested files. SAF scanning is provider-dependent. |
| Locale folder not found | Check for a locale directory such as enUS or enGB directly under Data. |
| realmlist file not found | Check whether the selected client already has Data/<locale>/realmlist.wtf; the app may create it when the expected locale directory is visible and writable. |
| DNS check fails | Check the hostname spelling and device network connection; the server may have a DNS issue. |
| TCP check fails | Check the host and port provided by the server operator. A firewall or server outage may block the connection. |
| TCP succeeds but login fails | TCP reachability does not verify WoW authentication, client version, realm routing, or game compatibility. |
| APK is unavailable | Wait for the single release workflow to finish successfully; a running or failed job does not have a valid APK artifact. |

## 👨‍💻 Development and tests

The main application is built with Flutter/Dart. Android-specific folder access is implemented in the native Android activity using Kotlin and a Flutter MethodChannel.

Key source areas:

- `lib/main.dart` — launcher screen, navigation, realm selection, and Android storage channel calls.
- `lib/game_folder_inspector.dart` — game folder inventory and inspector UI.
- `lib/server_manager.dart` — saved realm profiles and network diagnostics.
- `lib/mpq_checksum_scanner.dart` — streaming MPQ SHA-256 scanner for filesystem-accessible paths.
- `lib/mpq_checksum_manifest.dart` and `lib/mpq_manifest_manager.dart` — checksum baseline data and UI.
- `lib/mpq_scan_history.dart` — local scan history and comparisons.
- `android/app/src/main/kotlin/com/example/myapp/MainActivity.kt` — Android document-tree picker, folder enumeration, and realmlist write operations.
- `test/` — unit and widget tests.

Run checks before submitting changes:

```bash
flutter pub get
flutter analyze
flutter test
```

The repository uses one CI workflow to analyze, test, build a release APK, and upload the artifact. A successful CI build verifies compilation and automated tests only; it does not replace testing on a physical Android device.

## 🧭 Roadmap

Items below are plans, not claims that the feature is already complete.

- [ ] Complete SAF-based recursive MPQ streaming SHA-256 scanning.
- [ ] Connect SAF scan results to checksum baseline import/export and scan history.
- [ ] Add robust locale selection when more than one locale folder exists.
- [ ] Improve provider-specific storage error reporting and recovery.
- [ ] Expand device testing across Android versions and OEM file providers.
- [ ] Finish the Classic WoW-inspired visual treatment across every screen and dialog.
- [ ] Define and test a real Android game-runtime integration, if technically and legally feasible.
- [ ] Verify launch, login, realm selection, and gameplay separately on supported hardware before claiming mobile play support.

## 🤝 Contributing

Bug reports and pull requests are welcome. When reporting an issue, include:

- Android version and device model.
- App version / commit SHA.
- The folder-selection method and document provider used.
- A screenshot of the error with personal information hidden.
- The exact steps to reproduce the issue.

Do not upload WoW client files, account credentials, private server passwords, or personal backups in issues or pull requests. Keep bug reports focused on app code and reproducible behavior.

## ⚠️ Project limitations and disclaimer

World of Warcraft and related game assets are the property of their respective rights holders. This is an independent community project and is not affiliated with, endorsed by, or sponsored by Blizzard Entertainment.

This repository does not distribute Blizzard game data. Users are responsible for obtaining and using game files lawfully and following the applicable game terms and server rules.

The name "Play WoW on Mobile" describes the project's goal, not a guarantee that the current build can run the full PC game on Android. Runtime support must be demonstrated and tested before that claim can be made.

## License

No open-source license has been selected in this repository yet. Until a license is added, do not assume that the source code may be redistributed or reused. Choose a license before inviting outside contributors to reuse or redistribute the project.


## Integrated Android application build

The runtime/native-engine-import development branch now builds toward a single WOW LK Android package: the Flutter companion is embedded into the native WoW Mobile host application as an in-app Flutter screen. The Flutter companion is the launcher screen, and its OPEN GAME ENGINE action opens the native Winlator/Wine runtime launcher within the same app.

The current integration phase does not yet synchronize every Flutter companion feature with the native engine. In particular, the Flutter SAF-selected game folder and saved Realm Manager profiles are not yet automatically transferred into the native runtime's storage/configuration. Treat the integrated APK as an experimental development build until those bridges and real-device gameplay checks are complete.
