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


## 2026-11-16 native disconnect diagnostics build verification
- Latest branch head before this status update: `ad82878ca5b06f18f559954ab6872eddce61cafc`.
- Native runtime workflow run `43919075919` completed with conclusion **success** on commit `ad82878ca5b06f18f559954ab6872eddce61cafc`.
- All source-patch steps completed, including branding, SAF game-folder importer, and disconnect diagnostics; Gradle `assembleRelease` completed successfully; artifact upload completed.
- Artifact: `wow-mobile-native-runtime-unsigned`, artifact ID `14253390990`, size 164,430,347 bytes (~156.8 MiB), expires 2026-11-23.
- Workflow: https://github.com/madu011/play-wow-on-mobile/actions/runs/43919075919
- Artifact remains unsigned. Successful CI compilation does not establish installation, runtime stability, game compatibility, or successful realm connection on a physical Android device.
- Next device validation: install the APK on a supported Android device, import a valid WoW 3.3.5a folder, launch the client, reproduce the realm-selection disconnect, then collect and review the diagnostics TXT report. Verify whether the app can access useful Wine/Box64/runtime logs; if not, implement explicit runtime log capture before attempting to diagnose the world-server handoff.


## 2026-11-16 installable Android test artifact
- The successful release CI artifact is unsigned because no user-owned release keystore is configured. Do not ask the user to install that unsigned APK.
- Added a separate `assembleDebug` CI target to produce an APK signed with Android's standard debug key for device testing; the workflow verifies the signature with `apksigner` and uploads it as `wow-lk-debug-test-apk`.
- This debug-signed build is for testing only. It is not a public release or a replacement for a private release keystore.
- Awaiting CI confirmation of the debug build and signature verification before sharing it as installable.


## 2026-11-16 WOW LK keyboard, mouse, and touchscreen controls milestone
- Confirmed the pinned native engine already routes physical keyboard events to the X server, receives external mouse motion through its touchpad/pointer-capture path, and provides a Keyboard command in the in-game navigation drawer to open the Android soft keyboard.
- Added a dedicated built-in profile named `WoW ConsolePortLK`, which the existing WoW shortcut auto-selects by profile name.
- The profile provides a left-side WASD virtual joystick/D-pad and six labelled action buttons mapped to keyboard keys `1`, `2`, `3`, `5`, `6`, and `7`, plus ESC and SPACE utility buttons.
- Updated profile asset installation so a newly added built-in profile is copied on app upgrades when it is missing, while preserving an existing user profile file.
- The native controls editor can move, resize, and save profile elements; profiles are stored in app-private files and survive app restarts. Users can edit the WOW LK profile in Input Controls > Controls Editor.
- Added `scripts/apply-native-wow-controls.py` to install the profile and upgrade-safe profile-copy behavior into the pinned native engine. Added this patch to the native build workflow.
- Hardware detection/input behavior is inherited from the native engine; physical keyboard keys are forwarded to the game and external mouse movement is handled by the existing pointer path. The soft keyboard remains available from the in-game drawer's Keyboard item when no physical keyboard is connected.
- CI build and on-device validation are pending. Confirm the six key buttons, joystick, soft keyboard, external keyboard, and external mouse on a real device before marking the feature complete.


## 2026-11-16 Android keyboard and mouse detection diagnostics
- Latest touch-controls CI run 43920006009 completed successfully on commit 5619d64321cd868ede0c3bf26d32b36e18f8991c. All patch steps passed, native release APK compiled, debug APK compiled, signature verification passed, and both artifacts uploaded.
- Added Android input-device enumeration to the disconnect diagnostics report. It lists reported device names, virtual/physical classification, keyboard type, and advertised KEYBOARD / MOUSE / GAMEPAD / JOYSTICK sources.
- This helps verify whether Android recognizes a connected keyboard or mouse, separately from whether the game runtime receives its events. It does not force-enable unsupported peripherals or guarantee game-level input.
- The diagnostics screen remains available from the native launcher. Run it with peripherals connected to capture their recognition state.
- Build verification for this input-device diagnostics addition is pending; physical keyboard/mouse and touchscreen control tests are still required on a real Android device.


## 2026-11-16 integrated Android application — phase 1 implementation
- Integration target: one Android package based on the pinned native WoW Mobile application, with the existing Flutter companion compiled as an Android Archive (AAR) and hosted as an in-app FlutterActivity.
- The Flutter companion becomes the app's launcher screen. Its primary action opens the native WoW runtime launcher Activity inside the same installed package; this is an in-app Activity transition, not a second installed application.
- Added scripts/apply-native-flutter-companion.py to the native build pipeline. It wires the generated Flutter AAR Maven repository into the native Gradle build, adds the Flutter AAR dependency, registers the companion Activity, and moves the launcher intent filter to the Flutter screen.
- Added a native MethodChannel entry point for openNativeGameLauncher and a basic device-information response. The existing Flutter SAF folder picker, realmlist profile persistence, and native runtime game-folder import are not yet sharing data; that is the next integration phase.
- CI now builds the Flutter AAR with Flutter 3.35.7 before assembling the native application. The integrated debug APK is uploaded as wow-lk-integrated-debug-test-apk after signature verification.
- This phase is not complete until CI proves the merged APK builds. Even after CI succeeds, physical-device tests are required for Flutter screen startup, native launcher navigation, plugin registration, SAF import, game provisioning, and WoW launch.


## 2026-11-16 Flutter AAR integration pipeline correction
- Corrected the native CI ordering so Flutter 3.35.7 is installed and the Flutter AAR is built before the native patch script checks for the generated Maven artifact.
- Added the official Flutter engine Maven repository alongside the generated local Flutter AAR repository so the native Gradle app can resolve the Flutter embedding dependency.
- The integrated build is now the first validation of this add-to-app boundary; resolve any dependency-coordinate or Gradle compatibility issues from actual CI output before claiming integration complete.


## 2026-11-16 Flutter add-to-app module preparation
- The root Flutter project is a standard Flutter application, not a Flutter module. It cannot be assumed to emit an AAR directly.
- CI now creates a dedicated Flutter module host, copies the canonical root lib/ sources into it, and writes a module pubspec with the same runtime dependencies. This preserves the existing root Flutter app workflow while producing a proper add-to-app AAR for the native host.
- Updated the native integration patch to discover the generated release AAR Maven coordinates from its POM instead of hard-coding group/version assumptions.
- The integrated build remains pending; check the module generation, AAR build, dependency resolution, Java compilation, and final signed APK stages before claiming success.


## 2026-11-16 shared game-folder and Realm bridge — phase 2
- Extended the generated Flutter host MethodChannel with persistent SAF tree selection, locale scanning, and realmlist writing.
- Selecting the main WoW folder now invokes the existing native game-folder importer, validates and copies the client into app-owned storage, then writes the imported filesystem path to the Winlator preference key wow_game_folder.
- The selected SAF tree URI is retained across launches. Realm writes are applied to the selected source tree and mirrored into the imported app-owned game folder so the native Winlator F: drive uses the same selected realm.
- Import errors are returned to Flutter as a typed platform error; the native launcher will not be marked ready when the import fails.
- CI compilation is required before this phase can be considered build-verified. Physical-device validation remains required for large client import duration, available-storage checks, document-provider compatibility, process recreation, and verifying that the game launches using the selected realm.


## 2026-11-16 game import progress and cancellation bridge
- Added native-to-Flutter progress events for the SAF game-folder import, reporting the current relative file path and copied/total byte counts. Progress events are throttled to avoid flooding the platform channel.
- Added a visible import progress bar with percentage when provider file sizes are available, indeterminate progress otherwise, copied-byte totals, and a Cancel Import action.
- Added native cancellation via the importer's existing cancellation flag. Cancelling stops the copy at the next file-buffer boundary and the staged temporary import is cleaned up; the existing imported game remains preserved.
- Added a native method to return the app-owned imported game path after relaunch, so the Flutter game-folder inspector receives the actual imported filesystem path instead of a placeholder label.
- The updated APK must pass CI build and signature verification before being offered for device testing. Device testing remains necessary for real SAF providers, import progress, cancellation, and launch.


## 2026-11-16 import progress estimate accuracy
- Corrected the import-size preflight and progress denominator to recursively inspect nested files instead of adding only root-level file sizes.
- When a SAF provider does not expose a size for every file, the UI now receives an unknown total and uses an indeterminate progress bar rather than showing a misleading percentage.
- This does not replace runtime storage checks; Android may still report insufficient space during a copy if provider metadata is incomplete.


## 2026-11-16 integrated native runtime settings bridge
- Added Flutter MethodChannel actions that open the bundled WoW game settings, Winlator container editor, and touch-controls profile editor from the WOW LK Performance & Controls section.
- Added matching launcher tiles with clear descriptions. These open native activities inside the same installed WOW LK APK; they do not require a separate Winlator installation.
- The WoW settings screen applies realm, resolution, and view-distance values to the imported client configuration. The container editor exposes the existing Winlator graphics driver, DX wrapper, Box64, Wine, audio, environment, and drive configuration panels. The controls editor opens profile 0 for touch-layout editing.
- Updated the Flutter graphics helper copy so it no longer claims that the native runtime is not integrated. The heuristic preset remains a recommendation; actual runtime configuration is performed in the native settings screens.
- CI build and signature verification are required before distributing this revision. Physical-device validation is still required for activity launch, an existing container, profile availability, saving settings, and applying them to the game.

## 2026-11-16 — Hardware detection and Winlator auto configuration
- Added a native EGL graphics probe to report the Android GPU vendor, renderer, and OpenGL ES version instead of placeholder values.
- Device diagnostics now include total/available RAM and physical screen resolution; Vulkan availability is reported from Android's Vulkan hardware feature flag (not a benchmark or guarantee that every Vulkan wrapper will work).
- Added a native WOW LK Auto Tuner for the WoW Winlator container. It chooses a conservative starting combination of graphics driver, DX wrapper, Box64 preset, and container resolution from available RAM, CPU core count, Adreno detection, and Vulkan feature availability.
- Newly created WoW containers receive the hardware-based starting profile automatically.
- Existing containers can be updated explicitly using AUTO CONFIGURE WINLATOR in the Flutter companion. This saves settings into the actual native .container configuration; it does not just change the launcher recommendation.
- Manual container settings remain available. Auto configuration is an opt-in reset of the listed container settings and should be run again only when the user wants to replace manual values.
- The profile is a compatibility-first starting point, not a measured optimum. The DXVK path is selected only when Android reports Vulkan support; otherwise the tuner selects WineD3D. Physical-device build/install/gameplay testing is still required.
- CI validation is pending for the commit containing these changes. No device gameplay result is claimed.

## 2026-11-16 — Link the original WoW client in place (no duplicate copy)
- Replaced the previous SAF importer implementation with direct-folder resolution and validation. It no longer stages, copies, extracts, backs up, or duplicates WoW client files.
- The selected folder must be on a directly accessible Android shared-storage volume and contain readable Wow.exe plus a non-empty Data/ directory. Unsupported cloud/document providers are rejected with a clear explanation because Winlator cannot mount a content:// URI as a normal Wine filesystem drive without copying.
- The original absolute folder path is saved as the selected game path and mapped to the WoW container F: drive. Newly launched game shortcuts therefore point to the original client location.
- The launcher requests Android shared-storage read permission before linking the folder. The SAF tree permission is retained for locale discovery and direct realmlist updates.
- Updated the Flutter UI to say LINK ORIGINAL WOW GAME FOLDER and explain that files remain in their existing location. Removed the copy-progress/cancel UI.
- The previous import-oriented storage keys and method names remain for compatibility, but their value now represents the linked original folder path, not an imported copy.
- In-place validation checks readable Wow.exe, non-empty Data/common.MPQ, Data/expansion.MPQ, Data/lichking.MPQ, and at least one four-letter locale folder containing a readable non-empty locale.MPQ. It does not hash every archive or guarantee every patch is intact. No file duplication is performed. Device testing is still required to confirm the original path is readable by the Wine runtime on Android.


## 2026-11-23 — Validate game-folder contents through persisted SAF access
- Replaced the previous path-only resolver with real Storage Access Framework validation before the selected path is saved for Winlator.
- The selected tree must have persisted read and write permission, map to a path inside its storage volume, contain Wow.exe (or Wow-64.exe), and expose Data/common.MPQ, Data/expansion.MPQ, Data/lichking.MPQ, plus a locale directory containing a readable MPQ archive.
- Required files are probed through ContentResolver streams instead of relying on File.canRead()/File.isFile(), which can give misleading results under Android scoped storage.
- Cloud/document providers remain unsupported for direct Winlator drive mapping; the original game files are not copied or modified by folder selection.
- Commit: 6c29ab841c91fbc99c1dbff5cccd31265c1499f3.
- CI compilation and physical-device SAF permission validation are pending. Do not mark the game-folder workflow complete until the native workflow succeeds and the folder selection is tested on the target Android device.
