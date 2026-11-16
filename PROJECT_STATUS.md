# WOW LK / Azeroth Mobile — Project Status

Last updated: 2026-11-16

## Working agreement
- Work incrementally on the existing branch; do not restart or replace completed work without a reason.
- After each coherent implementation milestone, commit all related source, resources, tests, and documentation to GitHub.
- Run the relevant checks/build after each milestone and record the exact result. Never label an unsigned APK as install-ready or a successful compile as proof of gameplay.
- Keep this file updated in the same commit as each milestone so work can resume after a chat interruption.

## Repository checkpoint
- Repository: `madu011/play-wow-on-mobile`
- Working branch: `runtime/native-engine-import`
- Last previously verified branch head: `12415a4fd90fa8407886046caed74ca55dad5a45`
- Last previously verified native-runtime workflow run: `43914388690`
- Workflow: https://github.com/madu011/play-wow-on-mobile/actions/runs/43914388690
- Artifact: `wow-mobile-native-runtime-unsigned.zip`
- Artifact ID: `14249990715`
- Artifact contained `app-release-unsigned.apk` (~165 MB). It is unsigned and is not an ordinary install-ready release.

## Confirmed checkpoint
- Native runtime workflow completed successfully at the time it was checked.
- The APK contained ARM64 runtime assets/libraries, including Wine/Box64-related components.
- This confirms a successful build artifact, not successful installation or WoW gameplay on a physical phone.
- The earlier inspection found WoW-specific launcher/runtime source in the upstream native project, including a launcher activity, game-folder helper, provisioning helper, basic realm settings, and Winlator container launch path.
- The existing native launcher was still a basic layout; final WOW LK branding and Icecrown-style UI were not completed.
- The existing game-folder picker used legacy filesystem enumeration and needs a modern Android storage-access review before implementation.
- Basic realm configuration exists; a fuller Realm Manager is still a planned enhancement.

## Important repository consistency check
The current branch README describes a Flutter launcher/helper prototype and says it does not include a compatibility runtime. That statement may not describe the native-runtime artifact/source checkpoint above. Before changing architecture or editing app code, inspect the current branch tree and workflow sources and reconcile README, Gradle/native module, and actual CI artifact provenance. Do not assume the Flutter and native-runtime work are already integrated into one installable app.

## Remaining work — ordered
1. Reconcile the branch source tree, README, and native-runtime workflow/artifact provenance.
2. Define the actual app entry point and build target for the integrated WOW LK APK.
3. Complete WOW LK branding: app label, launcher icon, Icecrown-inspired launcher UI, typography, buttons, and navigation.
4. Implement a modern, robust game-folder import flow compatible with Android scoped storage and the runtime's filesystem requirements. Include validation, free-space checks, progress, cancellation/error handling, and no assumption that a SAF URI is directly mountable.
5. Upgrade the existing realm settings into a Realm Manager (profiles, add/edit/remove, active/default selection, validation, backup/restore) without breaking existing settings.
6. Connect the selected game folder and realm configuration to first-run provisioning and native runtime launch.
7. Add clear diagnostics for missing game files, unsupported storage providers, container setup, and launch failures.
8. Run CI/build and tests; then install and test on a real Android device. Record device/Android details and actual result.
9. Produce a signed release only after signing configuration and runtime testing are complete.

## Current implementation state
- Source implementation has since advanced: native SAF game-folder import and disconnect diagnostics are now committed; see the dated implementation checkpoints below.
- Flutter and native runtime remain separate build targets; they are not yet integrated into one APK.
- Continue from the latest dated checkpoint rather than treating this initial audit as the current state.


## 2026-11-16 architecture audit
- Confirmed this branch contains two distinct Android delivery paths:
  1. Flutter launcher CI (`.github/workflows/build-launcher-apk.yml`) builds the root Flutter project and uploads `play-wow-on-mobile-android`.
  2. Native runtime CI (`.github/workflows/native-runtime-build.yml`) builds the pinned upstream project under `vendor/wow-mobile-engine` and runs `scripts/apply-wowlk-branding.py` before assembling the native APK.
- The native workflow is triggered by pushes to this branch; the Flutter workflow is configured for pushes to `main` or manual dispatch.
- The native engine is pinned to upstream commit `0c8068f617737d9c0fb6246f37b54f85b620b09d`.
- This explains why the root README can describe the Flutter companion launcher while a separate CI workflow produces a native runtime APK. They are separate build targets, not proof that both have been integrated into one APK.
- Next inspection: branding script, submodule tree, and root Flutter navigation/import/realm flows. Then choose and implement a clearly defined integration boundary without replacing either working build path.


## 2026-11-16 existing-feature audit
- Root Flutter app already has an Android Storage Access Framework (SAF) folder-tree picker in `MainActivity.kt`, requests persistable read/write permissions, remembers the selected tree URI, scans the selected tree, and can write `Data/<locale>/realmlist.wtf`.
- Root Flutter app already has a Realm Manager in `lib/server_manager.dart`: saved profiles, add/remove, import/export JSON backups, parsing realmlist text, and DNS/TCP diagnostics. Do not rebuild these features from scratch.
- The root Flutter game-folder inspector can inspect document-tree selections through the Android method channel, while its MPQ SHA-256 scanner is separately filesystem-path based. Document-provider streaming hash support remains a known limitation.
- The native engine launcher is a separate Android app inside the pinned submodule. Its game-folder selection and realm settings are not yet connected to the root Flutter SAF picker or Realm Manager.
- The branding script currently changes native app label/subtitle and theme palette. It does not yet implement the complete launcher redesign or a custom WOW LK launcher icon.
- Therefore the next integration milestone must bridge the already-existing Flutter SAF/realm configuration to the native runtime (or implement equivalent supported storage/profile behavior in the native launcher). Merely improving the Flutter UI will not make the native engine use the selected game folder.


## Next implementation milestone: native runtime game-folder import
- Implement the import in the native engine app, not only in the Flutter companion launcher.
- Use Android's Storage Access Framework folder-tree picker and persist only the URI permissions actually granted.
- Because the Winlator game drive currently requires a real filesystem path, do not pass a `content://` URI as the F: drive path. Implement a controlled import/copy into the native app's accessible storage, or prove a supported filesystem bridge before choosing an alternative.
- The importer must validate the selected tree (root-level WoW executable and required Data structure), estimate available destination space, stream files without loading them all into memory, expose progress, handle cancellation/errors, and preserve the original source.
- Re-open and validate the imported folder after process restart; do not rely only on an in-memory URI or path.
- Keep the current native launch/container path intact and update its F: drive mapping only after a complete, validated import.
- Once this native import is working, connect realm profile selection and realmlist writing to the imported folder. The Flutter Realm Manager remains a separate existing feature until an explicit shared-data bridge is implemented.


## 2026-11-16 native SAF importer implementation checkpoint
- Added `native-patches/WowGameFolderImporter.java`: copies the selected SAF tree into app-owned storage, validates root-level `Wow.exe` and `Data/`, streams file contents, reports copied bytes, checks available space using sizes exposed by the provider, supports cancellation, stages into a temporary directory, and preserves/restores the previous import when finalizing fails.
- Added `scripts/apply-native-game-import.py`: installs the helper into the pinned native submodule and patches the native launcher to use `ACTION_OPEN_DOCUMENT_TREE` instead of its legacy manual filesystem browser.
- Updated `.github/workflows/native-runtime-build.yml` to apply the importer patch before building.
- The runtime still receives a normal filesystem path under the app-specific `wow-client/WoW` directory, not a `content://` URI.
- Source files are committed, but the new native build is still running. No successful compile or device import test is claimed yet.
- Known limitation to revisit after CI: some document providers omit file sizes from metadata, so the preflight free-space estimate may be incomplete. The copy operation will still report a storage error if the device runs out of space; improve recursive size estimation and user-facing recovery before calling this production-ready.
- Latest native build run for the importer workflow change: https://github.com/madu011/play-wow-on-mobile/actions/runs/43917972991
- Next: inspect CI output; fix compile issues, then test SAF import on a real Android device before connecting Realm Manager profiles to the imported folder.


## 2026-11-16 native disconnect diagnostics checkpoint
- Added `native-patches/WowDiagnosticsActivity.java` and `scripts/apply-native-diagnostics.py`.
- Added a **Disconnect Logs & Diagnostics** entry to the native launcher and registered the diagnostics activity in the manifest.
- The diagnostics screen creates a timestamped TXT report in app-private storage and can share it through the existing FileProvider.
- Report fields currently include Android/device/build details, selected game-folder presence, configured `realmlist.wtf` hostname, active network transport, DNS resolution results, TCP reachability of the configured login host on port 3724, and a filtered recent Android logcat excerpt.
- Basic redaction is applied to log lines for common credential-like fields. Reports should still be reviewed before sharing because diagnostic logs can contain device/network metadata.
- Important interpretation: a successful TCP test to login port 3724 does **not** prove the realm/world server is reachable. The game server endpoint is normally supplied after realm selection, so a realm-selection disconnect may require runtime/client logs that expose the negotiated world-server address. The current report does not yet capture that endpoint directly.
- Workflow patching initially exposed a malformed escaped YAML step; corrected in commit `5a85c77ddf1ad864d33acac844d7e96bf0e08ffe`. The diagnostics source regex for `set realmlist` was corrected in the same fix commit.
- Diagnostics implementation commit: `7bbd8a11015e43ea18212de23c90875f5c934831`.
- Latest corrected native workflow run: https://github.com/madu011/play-wow-on-mobile/actions/runs/43918851111
- At the time of this checkpoint, launcher branding, SAF importer patch, and diagnostics patch all completed in CI; native Gradle APK compilation was still running. Do not claim build success until that run completes.
- Physical Android testing is still required. In particular, confirm that the report contains the runtime/Wine/Box64 log entries needed to explain the actual realm disconnect.
