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

IMPORTER_TARGET.parent.mkdir(parents=True, exist_ok=True)
IMPORTER_TARGET.write_text(IMPORTER_SOURCE.read_text(encoding="utf-8"), encoding="utf-8")
ACTIVITY.write_text(text, encoding="utf-8")
print("Installed SAF-based native game-folder importer.")
