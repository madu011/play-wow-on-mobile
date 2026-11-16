# Security policy

## Reporting a vulnerability

Please do not publish passwords, private server credentials, account details, or exploit instructions in a public issue.

For a suspected security problem, contact the repository maintainer privately through the contact method listed on the GitHub profile. Include:
- A concise description of the issue.
- Affected app version or commit.
- Android version and device model.
- Reproduction steps that do not expose real account credentials.

## Sensitive data

- Do not add WoW account passwords or authentication tokens to the app, logs, issues, or test fixtures.
- Treat exported realm profile backups as potentially sensitive because they contain hostnames and profile names.
- Do not commit game client binaries, MPQ files, copyrighted assets, or private server account data.
- Avoid logging full filesystem paths if they may reveal a user's personal folder names.

## Scope and limitations

This is an experimental project. Folder access and network diagnostics are not a security audit of a WoW client or private server. A successful TCP check does not establish that a server is safe or that authentication is secure.
