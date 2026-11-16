# Contributing

Thanks for your interest in Play WoW on Mobile.

## Before opening an issue

- Search existing issues for the same problem.
- Use the latest available build from a successful workflow run.
- Include Android version, device model, app version/commit, and reproducible steps.
- Hide usernames, private server details, account names, and other personal information in screenshots.

## Before opening a pull request

1. Keep changes focused and explain the reason for the change.
2. Do not add copyrighted WoW game assets, executable files, MPQ archives, account data, or private-server credentials.
3. Run:
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```
4. Describe what was tested on an emulator and what was tested on a physical Android device.
5. Update README documentation when behavior, setup steps, or limitations change.

## Code expectations

- Keep Android-specific storage behavior behind the existing platform channel where practical.
- Treat Android Storage Access Framework URIs as document identifiers; do not assume they are ordinary filesystem paths.
- Never report a scan as complete if the provider did not expose all files.
- Keep checksum claims precise: a SHA-256 fingerprint is not an official integrity verdict without a trusted reference hash.
- Do not claim Android game-runtime compatibility until it has been demonstrated on real devices.

## Scope

This project currently focuses on a companion launcher, folder inspection, realm profiles, and diagnostics. Runtime integration is a separate feature area and should be proposed with a technical design, compatibility risks, and device test plan.
