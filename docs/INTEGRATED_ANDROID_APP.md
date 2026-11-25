# WOW LK integrated Android application

## Goal

Ship one installable Android package containing both the Flutter companion UI and the pinned native WoW Mobile runtime (Winlator/Wine/Box64 and its launcher).

The native WoW Mobile app remains the host because the runtime is tightly coupled to its Android activities, services, resources, native libraries, container manager and X server.

## Phase 1 — Flutter screen hosted in native application

- CI builds the root Flutter project as an Android Archive (AAR).
- The native host Gradle app consumes that AAR from the generated local Maven repository.
- WowLKCompanionActivity hosts the Flutter UI inside the same Android package.
- The Flutter companion is the launcher Activity.
- The Flutter OPEN GAME ENGINE action opens WowMobileActivity inside the same installed app.
- A MethodChannel entry point supports native game-launcher navigation and basic Android device information.

This phase does not yet synchronize the Flutter SAF tree URI or Realm Manager profiles with the native runtime. The native runtime still has its own game-folder import and realm settings. The companion's storage-dependent functions must not be represented as fully integrated until those bridges are implemented and tested.

## Phase 2 — Shared game-folder and realm configuration bridge

- Establish one canonical native app-owned game-folder location.
- Port the Flutter SAF selection/import contract to the native host, or expose the native importer's completion and final path to Flutter through a typed MethodChannel.
- Keep content:// URIs out of Wine drive mappings; only validated app-owned filesystem paths may be passed to the runtime.
- Expose native realm profile CRUD/import/export to Flutter, or define a versioned shared JSON contract and migrate existing profiles safely.
- Ensure backups, cancellation, permission revocation and process restarts are handled.

## Phase 3 — Runtime launch and diagnostics bridge

- Have the Flutter PLAY action call a native runtime readiness check.
- Return typed states for missing client, invalid client, provisioning, container setup, runtime failure and game launch.
- Pass the selected realm only after validating it and write settings only while WoW is stopped.
- Surface native diagnostics and log export in the companion UI.

## Acceptance gates

- One APK installs and shows the Flutter companion as the launcher screen.
- Flutter plugins initialize inside the native host.
- OPEN GAME ENGINE opens the native runtime launcher without a second package.
- SAF import persists after app restart and the runtime sees the imported filesystem path.
- Realm profile selected in Flutter is the realm actually used by the game.
- Native container and WoW process launch are verified on a physical supported Android device.
- Keep the LGPL-2.1 license and third-party notices and review all separately bundled components before redistribution.

A successful Gradle build proves only packaging/compilation. It does not prove gameplay or hardware compatibility.
