#!/usr/bin/env python3
"""Install the default WOW LK touchscreen action bar profile into the native runtime."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "vendor" / "wow-mobile-engine"
MANAGER = ENGINE / "app/src/main/java/com/winlator/inputcontrols/InputControlsManager.java"
ASSET_DIR = ENGINE / "app/src/main/assets/inputcontrols/profiles"
PROFILE_SOURCE = ROOT / "native-patches/wow-controls/controls-9000.icp"
PROFILE_TARGET = ASSET_DIR / "controls-9000.icp"

source = MANAGER.read_text(encoding="utf-8")
anchor = '''                if (targetFile != null) {
                    FileUtils.copy(context, assetPath, targetFile);
                }
'''
replacement = '''                if (targetFile != null) {
                    FileUtils.copy(context, assetPath, targetFile);
                }
                else {
                    // Install newly added built-in profiles on upgrades too, without
                    // overwriting a user-created profile that happens to share a filename.
                    File newProfileFile = new File(profilesDir, assetFile);
                    if (!newProfileFile.exists()) FileUtils.copy(context, assetPath, newProfileFile);
                }
'''
if replacement not in source:
    count = source.count(anchor)
    if count != 1:
        raise SystemExit(f"Expected exactly one profile-copy insertion point; found {count}")
    source = source.replace(anchor, replacement, 1)
    MANAGER.write_text(source, encoding="utf-8")

ASSET_DIR.mkdir(parents=True, exist_ok=True)
profile = PROFILE_SOURCE.read_text(encoding="utf-8")
if not PROFILE_TARGET.exists() or PROFILE_TARGET.read_text(encoding="utf-8") != profile:
    PROFILE_TARGET.write_text(profile, encoding="utf-8")

print("WOW LK touchscreen action-bar profile installed.")
