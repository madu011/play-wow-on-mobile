#!/usr/bin/env python3
"""Copy the canonical Flutter companion sources into the generated add-to-app module."""
from pathlib import Path
import shutil
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
SOURCE_LIB = ROOT / "lib"
MODULE = ROOT / "flutter_companion_module"
TARGET_LIB = MODULE / "lib"

if not (MODULE / ".android").is_dir():
    raise SystemExit("Flutter module host was not generated. Run flutter create --template=module first.")
if not SOURCE_LIB.is_dir():
    raise SystemExit("Root companion lib/ directory is missing.")

if TARGET_LIB.exists():
    shutil.rmtree(TARGET_LIB)
shutil.copytree(SOURCE_LIB, TARGET_LIB)

# Fetch the exact PNG committed by the user on main (not the older WebP substitute).
ICON_URL = "https://raw.githubusercontent.com/madu011/play-wow-on-mobile/main/file_0000000035e882109c3307bc96cfe6a9.png"
ICON_DIR = ROOT / "native-patches" / "app-icon"
ICON_DIR.mkdir(parents=True, exist_ok=True)
ICON_SOURCE = ICON_DIR / "wow-lk-user-supplied.png"
with urlopen(ICON_URL, timeout=60) as response:
    payload = response.read()
if not payload.startswith(b"\\x89PNG\\r\\n\\x1a\\n"):
    raise SystemExit("The repository's supplied icon did not download as a valid PNG.")
ICON_SOURCE.write_bytes(payload)
ASSET_DIR = MODULE / "assets"
ASSET_DIR.mkdir(parents=True, exist_ok=True)
shutil.copyfile(ICON_SOURCE, ASSET_DIR / "wow-lk-user-supplied.png")

(MODULE / "pubspec.yaml").write_text("""name: wowlk_companion
description: WOW LK Flutter companion embedded in the native Android host.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  file_picker: ^8.1.7
  shared_preferences: ^2.3.3
  crypto: ^3.0.6

flutter:
  module:
    androidX: true
    androidPackage: com.example.wowlk_companion
    iosBundleIdentifier: com.example.wowlkCompanion
  uses-material-design: true
  assets:
    - assets/wow-lk-user-supplied.png
""", encoding="utf-8")

print("Prepared Flutter add-to-app module from canonical root lib/ sources.")
