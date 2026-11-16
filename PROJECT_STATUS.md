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
- No source-code implementation changes have been made in this continuation yet.
- This file is the first progress-tracking commit for the continuation.
- Next task: inspect the current branch tree and workflow definitions to resolve the Flutter/native-runtime integration question before touching application code.


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
