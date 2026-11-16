# Azeroth Mobile

A Flutter launcher prototype for World of Warcraft: Wrath of the Lich King 3.3.5a.





## MPQ SHA-256 fingerprints

The Game Folder Inspector provides an on-demand SHA-256 scan of every MPQ file under `Data/`. It streams file contents rather than loading whole archives into memory and displays each relative path, file fingerprint, and any read errors. Non-MPQ files are ignored.

A fingerprint is a file identity value, not an automatic integrity verdict. To verify an archive, compare its SHA-256 value with a trusted checksum published for the exact same client distribution. The app does not bundle guessed or unofficial reference hashes, and calculating a hash does not repair or modify files.

## Game data integrity scan

The Game Folder Inspector recursively scans the selected `Data/` directory for MPQ archives. It reports the archive count, combined file size, zero-byte archives, and whether common WotLK archive names (`common.MPQ`, `common-2.MPQ`, `expansion.MPQ`, and `lichking.MPQ`) are present.

This is a read-only structural check. It does not open or validate MPQ archive contents, compare cryptographic checksums, or prove that a client is complete. Archive naming can vary between client distributions, so a missing-name warning is informational and should be checked against the exact client package.

## WoW executable metadata check

The Game Folder Inspector also examines the selected `Wow.exe` (or `Wow-64.exe`) as a Windows PE file. It reports the PE architecture and optional-header type, then scans the executable for a small set of known WotLK version strings, including the commonly associated `3.3.5.12340` marker.

**Important:** this is a heuristic string scan, not a full Windows VERSIONINFO resource parser or cryptographic verification. A matching marker is only a possible build match; a missing marker means the build is unknown, not necessarily incompatible. It does not prove the client is unmodified, validate game archives, or establish Android runtime/server compatibility. The executable is read only.

## Game Folder Inspector

After selecting a game folder, the launcher displays a read-only scan of its basic structure:

- Checks for the selected directory and a root-level `Wow.exe` or `Wow-64.exe`.
- Checks for `Data/` and standard locale directories such as `enUS/` or `enGB/`.
- Lists detected `realmlist.wtf` files.
- Counts MPQ archives inside detected locale directories.
- Provides a refresh control to run the scan again.

The inspector does not modify game files. A successful structural scan does not verify archive integrity, the exact 3.3.5a client build, server compatibility, or whether the game can run on Android. Android storage providers may also restrict direct filesystem access even after a folder is selected.

## Saved realm profiles

The launcher includes a **Server Manager** for saving multiple WotLK realmlist entries.

1. Enter an optional display name.
2. Paste a realmlist command such as `SET realmlist "logon.example.com"`, or paste a hostname.
3. If the server explicitly supplies a non-standard auth port, include it as `hostname:port`.
4. Select a saved profile to make it active.

Profiles are stored locally on the Android device using shared preferences.

#
## Realm connection diagnostics

The Server Manager connection-test control now runs two separate checks:

1. **DNS resolution** — asks the device's resolver for IP addresses for the saved hostname.
2. **TCP reachability** — attempts to open a TCP connection to the configured host and port, with a five-second timeout.
3. **Timing and error details** — shows DNS and TCP elapsed time and a network error message when available.

A successful TCP check only means that the selected address and port accepted a TCP connection at test time. It does **not** prove that WoW authentication works, that the realm is online, or that the Android game client is compatible. DNS or TCP failures can also be caused by the current Wi-Fi/mobile network, firewall rules, or temporary server downtime.

## Realm backup: import and export

Use the **IMPORT** and **EXPORT** controls in Server Manager to move saved realm profiles between devices.

- **Export** creates a versioned JSON backup named `azeroth-realms-backup.json`.
- **Import** reads a JSON backup selected through Android's file picker.
- Imported entries are validated before saving. Unsupported formats and invalid host/port values are rejected.
- Existing profiles are preserved; duplicate host-and-port entries in the backup are skipped.
- The selected active realm is not changed by importing a backup.

Keep the backup file somewhere private because it contains the server addresses you saved. It does not contain account passwords or game login details.

### What the realmlist can and cannot tell us

A WotLK realmlist entry identifies the authentication/logon endpoint. If no port is supplied, the launcher assumes the common WotLK auth port `3724`. The realmlist alone does **not** guarantee the server's client build, realm world address, world port, or compatibility. Those are supplied by the server's realm list and must be supported by the game client/runtime. Each saved profile also has a TCP reachability check for its auth host and port; a successful TCP check only confirms that a connection can be opened, not that WoW authentication or gameplay will work.

Use the realmlist line provided by the server. A website homepage URL is not necessarily a valid realmlist address.

## Applying a selected realm

When a WoW game folder has been selected, choosing a saved profile attempts to update the applicable `Data/<locale>/realmlist.wtf` file. Android storage permissions and the selected folder provider may restrict direct file writes; the app reports a write error if it cannot update the file.

Changing a realmlist does not itself launch the game or prove that a server is compatible. The runtime launch integration and real-server testing are still separate tasks.

## Build and validation

GitHub Actions workflow: `.github/workflows/build-launcher-apk.yml`

The workflow runs Flutter dependency resolution, static analysis, unit tests, and a release APK build, then uploads the APK as an artifact.


## MPQ SHA-256 fingerprints and local manifests

The Game Folder Inspector can stream-hash MPQ archives with SHA-256 and display each relative path, size, and digest. The scanner reads archives as a stream rather than loading entire files into memory.

The **Checksum Manifest** panel can:
- Save a local baseline for the selected game folder.
- Compare later scans and report unchanged, changed, added, and missing MPQ files.
- Import and export a versioned JSON manifest.

The local baseline is stored on the device and keyed to the selected folder path. JSON import/export allows a user-created baseline to be moved between devices. The manifest records its creation time and successful file hashes; unreadable files are excluded.

**Important:** a locally created baseline is only a snapshot of the files at that moment. It is not an official Blizzard checksum list, and saving a baseline from a modified or damaged client does not establish that the client is original. For authoritative verification, compare against trusted checksums for the exact same client distribution.


### Multiple named MPQ baselines

The Checksum Baseline Library supports multiple named snapshots for one selected game folder. Give each baseline a label such as "Clean install" or "Before update", select one to compare with the latest scan, and export or delete the selected entry. Imported JSON manifests are added as separately named baselines. Names must be unique within that folder's local library. Baselines remain local to the device unless exported; imported baselines are still user-provided reference snapshots, not official checksums.

### MPQ scan progress and cancellation

The SHA-256 scanner displays file-based progress, the archive currently being processed, and a completion summary with successful hashes, errors, bytes processed, and elapsed time. A scan can be cancelled between archives; if an archive is already being hashed, it is allowed to finish before the cancellation takes effect. A cancelled scan keeps the results for files completed before cancellation.

### Local MPQ scan history

The Game Folder Inspector keeps the 20 most recent MPQ scan summaries for each selected game folder on the device. Each entry records the date/time, completion or cancellation state, discovered and completed archive counts, successful hashes, read errors, processed bytes, and elapsed time. History stores summaries only; it does not retain archive contents or the full hash list. The history is local to the device and is not synchronized.

The history panel also provides a summary comparison: choose an older scan and compare it with the latest scan. It shows signed differences in successful hashes, read errors, completed/discovered files, processed bytes, and elapsed time. This is a comparison of scan summaries only; it does not identify which individual MPQ files changed because the history does not retain per-file fingerprints.

For detailed scan-to-scan comparison, scan history now retains per-file MPQ fingerprint snapshots for up to the five newest scans per game folder, while keeping up to 20 summary entries. The comparison identifies unchanged, changed, added, missing, and unreadable MPQ files by relative path and SHA-256 (and checks file size). Older history entries created before this feature remain readable but have summary-only data, so per-file comparison is unavailable for those entries. Only fingerprint metadata is stored; MPQ archive contents are never copied into history.

When either comparison scan was cancelled, files that were not reached by that scan are marked **Not verified** rather than incorrectly reported as added or missing.
