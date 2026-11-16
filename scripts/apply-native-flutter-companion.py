#!/usr/bin/env python3
"""Integrate the root Flutter companion into the pinned native WoW Android host."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "vendor" / "wow-mobile-engine"
AAR_POM = ROOT / "build" / "host" / "outputs" / "repo" / "com" / "example" / "myapp" / "flutter_release" / "1.0.0" / "flutter_release-1.0.0.pom"

def replace_once(path: Path, old: str, new: str):
    content = path.read_text(encoding="utf-8")
    count = content.count(old)
    if count == 0:
        if new in content:
            return
        raise SystemExit(f"Expected patch anchor not found in {path}: {old[:90]!r}")
    if count != 1:
        raise SystemExit(f"Expected one patch anchor in {path}, found {count}")
    path.write_text(content.replace(old, new), encoding="utf-8")

if not AAR_POM.is_file():
    raise SystemExit(f"Flutter AAR not found: {AAR_POM}. Check flutter build aar output and module coordinates.")

root_gradle = NATIVE / "build.gradle"
replace_once(root_gradle, "allprojects {\n    repositories {\n",
             'allprojects {\n    repositories {\n        maven { url "$rootDir/../../build/host/outputs/repo" }\n')

app_gradle = NATIVE / "app" / "build.gradle"
replace_once(app_gradle, "dependencies {\n",
             "dependencies {\n    implementation 'com.example.myapp:flutter_release:1.0.0'\n")

manifest = NATIVE / "app" / "src" / "main" / "AndroidManifest.xml"
replace_once(
    manifest,
    '''        <activity android:name="com.winlator.wowmobile.WowMobileActivity"
            android:theme="@style/AppThemeDark"
            android:exported="true"
            android:screenOrientation="sensor"
            android:configChanges="keyboard|keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize|density|navigation">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
''',
    '''        <activity android:name="com.winlator.wowmobile.WowMobileActivity"
            android:theme="@style/AppThemeDark"
            android:exported="false"
            android:screenOrientation="sensor"
            android:configChanges="keyboard|keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize|density|navigation" />

        <activity android:name="com.winlator.wowmobile.WowLKCompanionActivity"
            android:theme="@style/AppThemeDark"
            android:exported="true"
            android:launchMode="singleTop"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/AppThemeDark" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
''')

activity = NATIVE / "app" / "src" / "main" / "java" / "com" / "winlator" / "wowmobile" / "WowLKCompanionActivity.java"
activity.parent.mkdir(parents=True, exist_ok=True)
activity.write_text('''package com.winlator.wowmobile;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/** Hosts the existing Flutter companion UI inside the native WOW LK application. */
public class WowLKCompanionActivity extends FlutterActivity {
    private static final String CHANNEL = "wow.lk/storage";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if ("openNativeGameLauncher".equals(call.method)) {
                    startActivity(new Intent(this, WowMobileActivity.class));
                    result.success(true);
                } else if ("getDeviceInfo".equals(call.method)) {
                    result.success(readBasicDeviceInfo());
                } else {
                    result.notImplemented();
                }
            });
    }

    private Map<String, Object> readBasicDeviceInfo() {
        ActivityManager manager = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
        manager.getMemoryInfo(memory);
        Map<String, Object> info = new HashMap<>();
        info.put("manufacturer", Build.MANUFACTURER);
        info.put("brand", Build.BRAND);
        info.put("model", Build.MODEL);
        info.put("device", Build.DEVICE);
        info.put("androidVersion", Build.VERSION.RELEASE);
        info.put("sdkInt", Build.VERSION.SDK_INT);
        info.put("cpuCores", Runtime.getRuntime().availableProcessors());
        info.put("supportedAbis", Build.SUPPORTED_ABIS);
        info.put("totalRamMb", (int) (memory.totalMem / (1024L * 1024L)));
        info.put("availableRamMb", (int) (memory.availMem / (1024L * 1024L)));
        info.put("gpuVendor", "Not yet bridged");
        info.put("gpuRenderer", "Not yet bridged");
        info.put("openGlVersion", "Not yet bridged");
        info.put("vulkanVersion", "Not yet bridged");
        info.put("vulkanLevel", "Not yet bridged");
        info.put("graphicsApi", "Native engine device diagnostics available");
        info.put("screenResolution", "Not yet bridged");
        return info;
    }
}
''', encoding="utf-8")

print("Flutter companion integration patch applied.")
print("Launcher: Flutter companion Activity; native WoW launcher remains in the same APK.")
print("Pending bridge: SAF game-folder selection and Realm Manager profile synchronization.")
