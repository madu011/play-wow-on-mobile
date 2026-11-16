# Android WoW 3.3.5a Runtime Integration

## Decision

Use the existing dedicated WoW 3.3.5a Android implementation as the primary technical reference instead of attempting to assemble Wine, Box64, graphics drivers and an X server independently inside the current Flutter-only app.

Reference project: https://github.com/marcocastignoli/wow-mobile

- Purpose: Android launcher for the Windows WoW 3.3.5a (build 12340) client.
- Runtime foundation: Winlator with Wine + Box64.
- Controls reference: ConsolePortLK.
- The project requires users to supply their own game client files and does not distribute Blizzard game data.
- Its README specifies JDK 17, Android SDK platform 34, NDK 24.0.8215888 and CMake 3.22.1.
- License note in its README: Winlator base is LGPL-2.1; bundled components retain their individual licenses. Review the exact upstream LICENSE and THIRD_PARTY_NOTICES before copying or redistributing any code/assets.

## Current WOW LK architecture

WOW LK currently consists of Flutter UI and launcher settings, Android Kotlin MainActivity with a MethodChannel for device info and Storage Access Framework game-folder access, plus game-folder inspection and realmlist editing. It has no Wine/Box64 runtime, container/rootfs, graphics translation stack, runtime asset installer or game process supervisor.

The current Flutter APK therefore cannot run Wow.exe. Adding a button or a MethodChannel launch call alone would not provide a working runtime.

## Integration phases

### Phase A — Stabilize launcher
- Keep the Flutter UI as the branded front end.
- Ensure flutter analyze, flutter test and Android APK build all pass.
- Preserve game-folder permissions and realm profile data.
- Do not claim runtime readiness until a runtime package is installed and a process launch is verified.

### Phase B — Runtime source integration
- Pin an exact upstream commit/tag and archive checksum.
- Decide whether to port WOW LK branding/UI into the upstream Android app or embed its runtime module. Prefer the upstream app's runtime architecture if it is tightly coupled to Winlator internals.
- Bring in source and build scripts as a separately reviewable integration, not a binary APK copied into this project.
- Preserve required license files, notices, source availability and attribution.
- Keep Wine/Box64/rootfs/driver assets downloaded or built from documented pinned sources. Do not commit multi-gigabyte generated runtime assets or proprietary game data into Git.
- Add ARM64 ABI checks and device capability diagnostics.

### Phase C — Device compatibility
- Identify the actual GPU renderer and Android ABI on the target phone.
- Do not assume Turnip works on Mali GPUs; choose a graphics path supported by the target driver.
- Treat Vulkan feature reporting as capability information, not proof of Direct3D compatibility.
- Add a safe first-run container profile with conservative resolution and graphics settings.
- Make runtime setup resumable and verify each downloaded asset with SHA-256 before use.

### Phase D — Launch and input
- Import or select the user's own WoW 3.3.5a build 12340 folder.
- Validate Wow.exe, Data archives and locale before launch.
- Apply realm and graphics configuration only while the game is stopped, with backups and rollback.
- Start the game through the runtime process API, capture logs/exit status, and support clean shutdown.
- Implement touch controls as input events expected by the client/addon; test movement, camera, menu and chat independently.

### Phase E — Acceptance tests
- Runtime install succeeds from a clean app state.
- Runtime asset hashes verify.
- Container creates and starts.
- WoW process starts and exits cleanly.
- Realm configuration persists.
- No game files are bundled.
- Actual target-device test records GPU, driver, resolution, FPS, temperature/stability and errors.
- Only after those checks may the Play button be labelled READY.

## Current status

Architecture decision recorded. No runtime binaries, Wine/Box64 libraries, container image or game engine have been integrated yet. This document is a technical integration plan, not evidence of gameplay support.
