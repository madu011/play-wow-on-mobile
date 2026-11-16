#!/usr/bin/env python3
"""Apply WOW LK branding to the pinned WoW Mobile Android source tree."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "vendor" / "wow-mobile-engine"
STRINGS = ROOT / "app/src/main/res/values/strings.xml"
STYLES = ROOT / "app/src/main/res/values/styles.xml"


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text and old not in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one occurrence of {old!r} in {path}, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(STRINGS, '<string name="app_name">WoW Mobile</string>', '<string name="app_name">WOW LK</string>')
replace_once(STRINGS, '<string name="wow_subtitle">World of Warcraft 3.3.5a on Android</string>', '<string name="wow_subtitle">Wrath of the Lich King • Android</string>')

# Icecrown-inspired midnight-blue surfaces with restrained Classic-style gold accents.
replacements = {
    '<item name="colorAccent">#0288d1</item>': '<item name="colorAccent">#D7AD63</item>',
    '<item name="colorPrimary">#505963</item>': '<item name="colorPrimary">#24364D</item>',
    '<item name="colorPrimaryDark">#3f474f</item>': '<item name="colorPrimaryDark">#101A2B</item>',
    '<item name="colorPrimaryText">#fafafa</item>': '<item name="colorPrimaryText">#F2F5FA</item>',
    '<item name="colorSecondaryText">#9e9e9e</item>': '<item name="colorSecondaryText">#A8B8CC</item>',
    '<item name="colorPrimarySurface">#1b1e21</item>': '<item name="colorPrimarySurface">#0B1422</item>',
    '<item name="colorSecondarySurface">#2d3238</item>': '<item name="colorSecondarySurface">#162338</item>',
    '<item name="colorPrimaryVariant">#56677a</item>': '<item name="colorPrimaryVariant">#6F91B5</item>',
    '<item name="colorSecondaryVariant">#37424f</item>': '<item name="colorSecondaryVariant">#30445F</item>',
}
for old, new in replacements.items():
    replace_once(STYLES, old, new)

print("WOW LK native launcher branding applied.")
