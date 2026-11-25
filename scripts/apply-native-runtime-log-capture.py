#!/usr/bin/env python3
"""Capture native Wine/Box64 guest stdout and stderr into a bounded private log."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "vendor" / "wow-mobile-engine"
ACTIVITY = ENGINE / "app/src/main/java/com/winlator/XServerDisplayActivity.java"

text = ACTIVITY.read_text(encoding="utf-8")
if "WOW_LK_RUNTIME_LOG_CAPTURE" in text:
    print("WOW LK runtime log capture already installed.")
    raise SystemExit(0)

imports = [
    ("import java.io.BufferedWriter;\n", "import java.io.File;\n"),
    ("import java.io.FileOutputStream;\n", "import java.io.File;\n"),
    ("import java.io.OutputStreamWriter;\n", "import java.io.File;\n"),
    ("import java.nio.charset.StandardCharsets;\n", "import java.util.ArrayList;\n"),
    ("import com.winlator.core.Callback;\n", "import com.winlator.core.AppUtils;\n"),
]
for line, anchor in imports:
    if line not in text:
        if anchor not in text:
            raise SystemExit(f"Cannot find import anchor: {anchor.strip()}")
        text = text.replace(anchor, anchor + line, 1)

field_anchor = "    private String screenEffectProfile;\n"
field_add = """    private String screenEffectProfile;
    // WOW_LK_RUNTIME_LOG_CAPTURE: capture Box64/Wine stdout and stderr even when UI debug is off.
    private final Object runtimeLogLock = new Object();
    private BufferedWriter runtimeLogWriter;
    private Callback<String> runtimeLogCallback;
"""
if field_anchor not in text:
    raise SystemExit("Cannot find XServerDisplayActivity field insertion point.")
text = text.replace(field_anchor, field_add, 1)

callback_anchor = "        if (enableLogs) ProcessHelper.addDebugCallback(debugDialog = new DebugDialog(this));\n"
if callback_anchor not in text:
    raise SystemExit("Cannot find ProcessHelper debug callback setup.")
text = text.replace(callback_anchor, callback_anchor + "        startRuntimeLogCapture();\n", 1)

destroy_anchor = """        winHandler.stop();
        if (environment != null) environment.stopEnvironmentComponents();
        super.onDestroy();
"""
destroy_replacement = """        winHandler.stop();
        if (environment != null) environment.stopEnvironmentComponents();
        stopRuntimeLogCapture();
        super.onDestroy();
"""
if destroy_anchor not in text:
    raise SystemExit("Cannot find XServerDisplayActivity onDestroy block.")
text = text.replace(destroy_anchor, destroy_replacement, 1)

method_anchor = "    private void setupUI() {\n"
methods = """    private void startRuntimeLogCapture() {
        try {
            File directory = new File(getFilesDir(), "diagnostics");
            if (!directory.isDirectory() && !directory.mkdirs()) return;
            File logFile = new File(directory, "wowlk-runtime-session.log");
            if (logFile.length() > 2 * 1024 * 1024) logFile.delete();
            runtimeLogWriter = new BufferedWriter(new OutputStreamWriter(
                    new FileOutputStream(logFile, false), StandardCharsets.UTF_8));
            runtimeLogCallback = line -> {
                synchronized (runtimeLogLock) {
                    if (runtimeLogWriter == null) return;
                    try {
                        if (logFile.length() > 2 * 1024 * 1024) {
                            runtimeLogWriter.close();
                            runtimeLogWriter = null;
                            return;
                        }
                        runtimeLogWriter.write(line == null ? "" : line.replaceAll("[\\r\\n]", " "));
                        runtimeLogWriter.newLine();
                        runtimeLogWriter.flush();
                    } catch (Exception error) {
                        try { runtimeLogWriter.close(); } catch (Exception ignored) {}
                        runtimeLogWriter = null;
                    }
                }
            };
            ProcessHelper.addDebugCallback(runtimeLogCallback);
            runtimeLogWriter.write("WOW LK runtime session started: " + new java.util.Date());
            runtimeLogWriter.newLine();
            runtimeLogWriter.flush();
        } catch (Exception ignored) {
            runtimeLogWriter = null;
        }
    }

    private void stopRuntimeLogCapture() {
        synchronized (runtimeLogLock) {
            if (runtimeLogCallback != null) {
                ProcessHelper.removeDebugCallback(runtimeLogCallback);
                runtimeLogCallback = null;
            }
            if (runtimeLogWriter != null) {
                try {
                    runtimeLogWriter.write("WOW LK runtime session ended: " + new java.util.Date());
                    runtimeLogWriter.newLine();
                    runtimeLogWriter.flush();
                    runtimeLogWriter.close();
                } catch (Exception ignored) {}
                runtimeLogWriter = null;
            }
        }
    }

"""
if method_anchor not in text:
    raise SystemExit("Cannot find setupUI method insertion point.")
text = text.replace(method_anchor, methods + method_anchor, 1)
ACTIVITY.write_text(text, encoding="utf-8")
print("WOW LK bounded Wine/Box64 runtime log capture installed.")
