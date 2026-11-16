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
