#!/usr/bin/env python3
"""Apply WOW LK branding and the exact user-supplied Icecrown dragon icon."""
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[1]
ENGINE=ROOT/"vendor"/"wow-mobile-engine"
RES=ENGINE/"app/src/main/res"
PATCH=ROOT/"native-patches"/"app-icon"/"wow-lk-dragon.webp"
STRINGS=RES/"values/strings.xml"
STYLES=RES/"values/styles.xml"
def replace_once(path,old,new):
    data=path.read_text(encoding="utf-8")
    if new in data and old not in data: return
    if old not in data: raise SystemExit(f"Expected {old!r} in {path}")
    path.write_text(data.replace(old,new),encoding="utf-8")
replace_once(STRINGS,'<string name="app_name">WoW Mobile</string>','<string name="app_name">WOW LK</string>')
replace_once(STRINGS,'<string name="wow_subtitle">World of Warcraft 3.3.5a on Android</string>','<string name="wow_subtitle">Wrath of the Lich King • Android</string>')
for old,new in {
'<item name="colorAccent">#0288d1</item>':'<item name="colorAccent">#D7AD63</item>',
'<item name="colorPrimary">#505963</item>':'<item name="colorPrimary">#24364D</item>',
'<item name="colorPrimaryDark">#3f474f</item>':'<item name="colorPrimaryDark">#101A2B</item>',
'<item name="colorPrimaryText">#fafafa</item>':'<item name="colorPrimaryText">#F2F5FA</item>',
'<item name="colorSecondaryText">#9e9e9e</item>':'<item name="colorSecondaryText">#A8B8CC</item>',
'<item name="colorPrimarySurface">#1b1e21</item>':'<item name="colorPrimarySurface">#0B1422</item>',
'<item name="colorSecondarySurface">#2d3238</item>':'<item name="colorSecondarySurface">#162338</item>',
'<item name="colorPrimaryVariant">#56677a</item>':'<item name="colorPrimaryVariant">#6F91B5</item>',
'<item name="colorSecondaryVariant">#37424f</item>':'<item name="colorSecondaryVariant">#30445F</item>'
}.items(): replace_once(STYLES,old,new)
if not PATCH.is_file(): raise SystemExit(f"Missing supplied app icon: {PATCH}")
for density in ("mdpi","hdpi","xhdpi","xxhdpi","xxxhdpi"):
    target=RES/f"mipmap-{density}"/"ic_launcher.webp"
    target.parent.mkdir(parents=True,exist_ok=True)
    legacy=target.with_suffix(".png")
    if legacy.exists(): legacy.unlink()
    shutil.copyfile(PATCH,target)
drawable=RES/"drawable"
drawable.mkdir(parents=True,exist_ok=True)
# Keep the adaptive icon foreground independent from ic_launcher itself.
# Referencing @mipmap/ic_launcher here creates a recursive adaptive-icon resource.
nodpi=RES/"drawable-nodpi"
nodpi.mkdir(parents=True,exist_ok=True)
shutil.copyfile(PATCH,nodpi/"wowlk_dragon_foreground.webp")
(drawable/"ic_wowlk_supplied_foreground.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<inset xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@drawable/wowlk_dragon_foreground"
    android:inset="0%" />
''',encoding="utf-8")
(RES/"values"/"wowlk_icon_colors.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources><color name="wowlk_icon_background">#061226</color></resources>
''',encoding="utf-8")
adaptive='''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/wowlk_icon_background" />
    <foreground android:drawable="@drawable/ic_wowlk_supplied_foreground" />
</adaptive-icon>
'''
for name in ("ic_launcher.xml","ic_launcher_round.xml"):
    (RES/"mipmap-anydpi-v26"/name).write_text(adaptive,encoding="utf-8")
print("WOW LK: exact supplied dragon artwork installed as the sole launcher icon.")
