#!/usr/bin/env python3
"""Install the WOW LK SAF game-folder importer into the pinned native engine."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "vendor" / "wow-mobile-engine"
ACTIVITY = ENGINE / "app/src/main/java/com/winlator/wowmobile/WowMobileActivity.java"
IMPORTER_SOURCE = ROOT / "native-patches/WowGameFolderImporter.java"
IMPORTER_TARGET = ENGINE / "app/src/main/java/com/winlator/wowmobile/WowGameFolderImporter.java"

text = ACTIVITY.read_text(encoding="utf-8")
if "WowGameFolderImporter.importTree" in text:
    print("Native game-folder importer already applied.")
    raise SystemExit(0)

for import_line in [
    "import android.app.ProgressDialog;\n",
    "import android.net.Uri;\n",
    "import android.provider.Settings;\n",
    "import android.os.Build;\n",
    "import android.widget.Toast;\n",
    "import java.util.concurrent.atomic.AtomicBoolean;\n",
]:
    if import_line not in text:
        anchor = "import android.app.AlertDialog;\n" if "android.app." in import_line else (
            "import android.os.Bundle;\n" if "android.net.Uri" in import_line else
            "import java.util.concurrent.Executors;\n"
        )
        if anchor not in text:
            raise SystemExit(f"Cannot find import anchor: {anchor.strip()}")
        text = text.replace(anchor, anchor + import_line, 1)

text = text.replace(
    "    private final PreloaderDialog preloaderDialog = new PreloaderDialog(this);",
    "    private final PreloaderDialog preloaderDialog = new PreloaderDialog(this);\n"
    "    private static final int REQUEST_WOW_GAME_TREE = 7413;\n"
    "    private AtomicBoolean importCancelled;"
)
text = text.replace(
    "    private AtomicBoolean importCancelled;",
    "    private AtomicBoolean importCancelled;\n    private boolean autoPlayRequested;"
)
text = text.replace(
    "        if (!requestAppPermissions()) RootFSInstaller.installIfNeeded(this);",
    '        autoPlayRequested = getIntent().getBooleanExtra("wow.lk.AUTO_PLAY", false);\n'
    '        if (!requestAppPermissions()) {\n'
    '            RootFSInstaller.installIfNeeded(this);\n'
    '            if (autoPlayRequested) waitForRootFsAndLaunch(600);\n'
    '        }'
)
text = text.replace(
    '                updateStatus();\n            }\n            else finish();',
    '                updateStatus();\n                if (autoPlayRequested) waitForRootFsAndLaunch(600);\n'
    '            }\n            else finish();'
)
method = """
    private void waitForRootFsAndLaunch(int attemptsLeft) {
        if (!autoPlayRequested || isFinishing()) return;
        com.winlator.xenvironment.RootFS rootFS = com.winlator.xenvironment.RootFS.find(this);
        if (rootFS.isValid() && rootFS.getVersion() >= RootFSInstaller.LATEST_VERSION) {
            autoPlayRequested = false;
            onPlay();
            return;
        }
        if (attemptsLeft <= 0) {
            autoPlayRequested = false;
            Toast.makeText(this, "Winlator system files are not ready. Please try Play again.", Toast.LENGTH_LONG).show();
            return;
        }
        new Handler().postDelayed(() -> waitForRootFsAndLaunch(attemptsLeft - 1), 1000);
    }

"""
text = text.replace("    private void onPlay() {", method + "    private void onPlay() {")

activity_result = """
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQUEST_WOW_GAME_TREE) return;
        if (resultCode != RESULT_OK || data == null || data.getData() == null) return;

        Uri treeUri = data.getData();
        int flags = data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        try {
            getContentResolver().takePersistableUriPermission(treeUri, flags);
            File originalGameFolder = WowGameFolderImporter.resolveAndValidateTree(this, treeUri);
            preferences.edit().putString(PREF_GAME_FOLDER, originalGameFolder.getAbsolutePath()).apply();
            updateStatus();
            Toast.makeText(this, "Original WoW folder linked. No game files were copied.", Toast.LENGTH_LONG).show();
        } catch (Exception error) {
            Toast.makeText(this, error.getMessage() == null ? "Could not access the original WoW folder." : error.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

"""
anchor = "    @Override\n    protected void onResume() {"
if anchor not in text:
    raise SystemExit("Cannot find onResume insertion point.")
text = text.replace(anchor, activity_result + anchor, 1)

start = text.find("    private void showFolderPicker() {")
if start < 0:
    raise SystemExit("Cannot find legacy folder picker.")
replacement = """
    private void showFolderPicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION |
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION |
            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(intent, REQUEST_WOW_GAME_TREE);
    }
"""
text = text[:start] + replacement + "\n}\n"


# Keep the native host activity invisible when it is only being used as a game launcher.
# The WOW LK Flutter activity remains the only visible app home screen.
text = text.replace(
    "        setContentView(R.layout.wow_main_activity);",
    '        autoPlayRequested = getIntent().getBooleanExtra("wow.lk.AUTO_PLAY", false);\\n'
    '        setContentView(R.layout.wow_main_activity);\\n'
    '        if (autoPlayRequested) getWindow().getDecorView().setVisibility(View.INVISIBLE);'
)
# Modern Android requires the special all-files access permission for the native
# Winlator process to read an arbitrary existing game folder through File paths.
text = text.replace(
    "        autoPlayRequested = getIntent().getBooleanExtra(\"wow.lk.AUTO_PLAY\", false);\\n"
    "        if (!requestAppPermissions()) {\\n"
    "            RootFSInstaller.installIfNeeded(this);\\n"
    "            if (autoPlayRequested) waitForRootFsAndLaunch(600);\\n"
    "        }",
    "        if (Build.VERSION.SDK_INT >= 30) {\\n"
    "            if (autoPlayRequested && !Environment.isExternalStorageManager()) {\\n"
    "                Intent access = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse(\"package:\" + getPackageName()));\\n"
    "                startActivity(access);\\n"
    "            } else {\\n"
    "                RootFSInstaller.installIfNeeded(this);\\n"
    "                if (autoPlayRequested) waitForRootFsAndLaunch(600);\\n"
    "            }\\n"
    "        } else if (!requestAppPermissions()) {\\n"
    "            RootFSInstaller.installIfNeeded(this);\\n"
    "            if (autoPlayRequested) waitForRootFsAndLaunch(600);\\n"
    "        }"
)
# On return from Android's special permission screen, continue the pending launch.
text = text.replace(
    "    protected void onResume() {\\n        super.onResume();",
    "    protected void onResume() {\\n        super.onResume();\\n"
    "        if (autoPlayRequested && Build.VERSION.SDK_INT >= 30) {\\n"
    "            if (Environment.isExternalStorageManager()) waitForRootFsAndLaunch(600);\\n"
    "            else if (getIntent().getBooleanExtra(\"wow.lk.AUTO_PLAY\", false)) {\\n"
    "                Toast.makeText(this, \"Allow All files access to start WoW from the selected folder.\", Toast.LENGTH_LONG).show();\\n"
    "                autoPlayRequested = false; finish(); return;\\n"
    "            }\\n"
    "        }"
)
# Do not leave the hidden native home activity underneath the game.
text = text.replace(
    "                    startActivity(helper.createLaunchIntent(container, shortcutFile));",
    "                    startActivity(helper.createLaunchIntent(container, shortcutFile));\\n"
    "                    if (autoPlayRequested) finish();"
)

IMPORTER_TARGET.parent.mkdir(parents=True, exist_ok=True)
IMPORTER_TARGET.write_text(IMPORTER_SOURCE.read_text(encoding="utf-8"), encoding="utf-8")
ACTIVITY.write_text(text, encoding="utf-8")
print("Installed SAF-based native game-folder importer.")
