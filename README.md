# Azeroth Mobile

A Flutter launcher prototype for World of Warcraft: Wrath of the Lich King 3.3.5a.

## Saved realm profiles

The launcher includes a **Server Manager** for saving multiple WotLK realmlist entries.

1. Enter an optional display name.
2. Paste a realmlist command such as `SET realmlist "logon.example.com"`, or paste a hostname.
3. If the server explicitly supplies a non-standard auth port, include it as `hostname:port`.
4. Select a saved profile to make it active.

Profiles are stored locally on the Android device using shared preferences.

### Realm backup: import and export

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
