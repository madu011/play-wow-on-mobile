#!/usr/bin/env python3
"""Add a persistent in-game soft-keyboard button to the native XServer display."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "vendor" / "wow-mobile-engine"
ACTIVITY = ENGINE / "app/src/main/java/com/winlator/XServerDisplayActivity.java"

text = ACTIVITY.read_text(encoding="utf-8")
if "WOW_LK_SOFT_KEYBOARD_BUTTON" in text:
    print("WOW LK in-game keyboard button already installed.")
    raise SystemExit(0)

for import_line, anchor in [
    ("import android.view.Gravity;\n", "import android.view.FrameMetrics;\n"),
    ("import android.widget.Button;\n", "import android.widget.ArrayAdapter;\n"),
]:
    if import_line not in text:
        if anchor not in text:
            # Gravity is inserted beside the existing view imports.
            anchor = "import android.view.View;\n" if "android.view.Gravity" in import_line else "import android.widget.ArrayAdapter;\n"
        if anchor not in text:
            raise SystemExit(f"Cannot find import anchor: {anchor.strip()}")
        text = text.replace(anchor, anchor + import_line, 1)

anchor = """        inputControlsView.setVisibility(View.GONE);
        rootView.addView(inputControlsView);
"""
addition = """        inputControlsView.setVisibility(View.GONE);
        rootView.addView(inputControlsView);

        // WOW_LK_SOFT_KEYBOARD_BUTTON: always-visible shortcut while the game is running.
        Button keyboardButton = new Button(this);
        keyboardButton.setText("⌨ Keyboard");
        keyboardButton.setAllCaps(false);
        keyboardButton.setTextSize(12);
        keyboardButton.setContentDescription("Open Android on-screen keyboard");
        keyboardButton.setAlpha(0.92f);
        keyboardButton.setMinWidth(0);
        keyboardButton.setMinimumWidth(0);
        keyboardButton.setPadding(12, 4, 12, 4);
        keyboardButton.setOnClickListener(v -> AppUtils.showKeyboard(this));
        FrameLayout.LayoutParams keyboardParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.END | Gravity.TOP);
        int keyboardMargin = (int) (12 * getResources().getDisplayMetrics().density);
        keyboardParams.setMargins(keyboardMargin, keyboardMargin, keyboardMargin, keyboardMargin);
        keyboardButton.setElevation(16 * getResources().getDisplayMetrics().density);
        rootView.addView(keyboardButton, keyboardParams);
"""
if anchor not in text:
    raise SystemExit("Cannot find InputControlsView insertion point in XServerDisplayActivity.")
text = text.replace(anchor, addition, 1)
ACTIVITY.write_text(text, encoding="utf-8")
print("WOW LK persistent in-game soft-keyboard button installed.")
