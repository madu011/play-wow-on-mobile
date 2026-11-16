#!/usr/bin/env python3
"""Install the WOW LK disconnect diagnostics screen into the pinned native engine."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "vendor" / "wow-mobile-engine"
JAVA_SOURCE = ROOT / "native-patches/WowDiagnosticsActivity.java"
JAVA_TARGET = ENGINE / "app/src/main/java/com/winlator/wowmobile/WowDiagnosticsActivity.java"
MANIFEST = ENGINE / "app/src/main/AndroidManifest.xml"
LAYOUT = ENGINE / "app/src/main/res/layout/wow_main_activity.xml"
ACTIVITY = ENGINE / "app/src/main/java/com/winlator/wowmobile/WowMobileActivity.java"

manifest = MANIFEST.read_text(encoding="utf-8")
layout = LAYOUT.read_text(encoding="utf-8")
activity = ACTIVITY.read_text(encoding="utf-8")

if 'android:name="com.winlator.wowmobile.WowDiagnosticsActivity"' not in manifest:
    anchor = '        <activity android:name="com.winlator.wowmobile.WowSettingsActivity"'
    if anchor not in manifest:
        raise SystemExit("Cannot find WowSettingsActivity manifest insertion point.")
    manifest = manifest.replace(anchor,
        '        <activity android:name="com.winlator.wowmobile.WowDiagnosticsActivity"\n'
        '            android:theme="@style/AppThemeDark"\n'
        '            android:exported="false" />\n\n' + anchor, 1)

if 'android:id="@+id/BTDiagnostics"' not in layout:
    anchor = '            <Button\n                android:id="@+id/BTAdvanced"'
    button = '''            <Button
                android:id="@+id/BTDiagnostics"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginTop="8dp"
                android:text="Disconnect Logs &amp; Diagnostics" />

'''
    if anchor not in layout:
        raise SystemExit("Cannot find advanced button layout insertion point.")
    layout = layout.replace(anchor, button + anchor, 1)

if "BTDiagnostics" not in activity:
    anchor = '        findViewById(R.id.BTAdvanced).setOnClickListener((v) -> startActivity(new Intent(this, MainActivity.class)));'
    if anchor not in activity:
        raise SystemExit("Cannot find native home activity button insertion point.")
    activity = activity.replace(anchor, anchor + '\n'
        '        findViewById(R.id.BTDiagnostics).setOnClickListener((v) -> startActivity(new Intent(this, WowDiagnosticsActivity.class)));', 1)

JAVA_TARGET.parent.mkdir(parents=True, exist_ok=True)
JAVA_TARGET.write_text(JAVA_SOURCE.read_text(encoding="utf-8"), encoding="utf-8")
MANIFEST.write_text(manifest, encoding="utf-8")
LAYOUT.write_text(layout, encoding="utf-8")
ACTIVITY.write_text(activity, encoding="utf-8")
print("WOW LK disconnect diagnostics screen installed.")
