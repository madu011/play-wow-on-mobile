# Native runtime migration branch

This branch begins the native runtime migration without destabilizing the existing Flutter launcher on `main`.

## Pinned engine source

- Upstream: https://github.com/marcocastignoli/wow-mobile
- Submodule path: `vendor/wow-mobile-engine`
- Pinned upstream commit: `0c8068f617737d9c0fb6246f37b54f85b620b09d`
- Upstream project license: LGPL-2.1. Preserve its license and review every bundled component's license before redistribution.

Clone with submodules enabled:

```sh
git clone --recurse-submodules https://github.com/madu011/play-wow-on-mobile.git
cd play-wow-on-mobile
git checkout runtime/native-engine-import
git submodule update --init --recursive
```

## What this step accomplishes

The full upstream native Android engine is now pinned as a Git submodule on this isolated migration branch. It retains the upstream source history and avoids duplicating hundreds of Java/C++ files and large runtime archives into the Flutter repository.

## What it does not accomplish

- The Flutter app does not yet invoke the native engine.
- The existing APK does not contain Wine, Box64, rootfs or graphics-driver runtime assets.
- No game process has been launched by WOW LK.
- The submodule is not yet wired into the existing Android Gradle build.

## Next implementation tasks

1. Build the upstream submodule independently with its documented JDK 17 / SDK 34 / NDK 24.0.8215888 / CMake 3.22.1 toolchain.
2. Create a migration build variant/application ID so the existing WOW LK APK and the experimental native runtime APK can coexist during testing.
3. Adapt branding and the WoW-specific launcher screens in the native application while retaining Winlator's container, X-server, process and input lifecycles.
4. Port game-folder import and realm configuration using Android Storage Access Framework permissions; do not assume Flutter's persisted URI grants automatically transfer between package IDs.
5. Audit asset and library licenses, ABI compatibility and target GPU support.
6. Verify clean install, runtime setup, container start, game launch and shutdown on a physical device before calling the runtime ready.


## Native engine CI build

A dedicated GitHub Actions workflow now checks out the pinned submodule recursively, verifies the exact upstream commit, installs JDK 17 / Android SDK 34 / NDK 24.0.8215888 / CMake 3.22.1, and runs the upstream `assembleRelease` task. The output is uploaded as an unsigned CI artifact for build verification. This workflow builds the upstream engine as-is; it does not yet produce a branded WOW LK integrated app.


## First native launcher branding pass

A repeatable script (`scripts/apply-wowlk-branding.py`) now patches the upstream native launcher's app name and subtitle to WOW LK and applies a midnight-blue / restrained gold theme palette to the native dark theme before CI builds the APK. The upstream submodule remains pinned and unmodified in Git; the patch is applied in the CI checkout. This is an initial palette/string pass only: the launcher layout, app icon and full Icecrown artwork are not yet ported.


## First upstream native APK build result

GitHub Actions run #138 completed successfully. The pinned upstream Android application compiled with the specified JDK/SDK/NDK/CMake toolchain and uploaded an unsigned CI APK artifact (`wow-mobile-native-runtime-unsigned`, approximately 164 MB). This verifies that the upstream native engine source can be built in CI from the submodule. It is still the upstream WoW Mobile app, not yet a WOW LK-integrated release, and it has not been installed or tested on the target phone.
