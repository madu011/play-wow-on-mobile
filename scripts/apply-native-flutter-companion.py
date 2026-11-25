#!/usr/bin/env python3
"""Integrate the root Flutter companion into the pinned native WoW Android host."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "vendor" / "wow-mobile-engine"
AAR_REPO = ROOT / "flutter_companion_module" / "build" / "host" / "outputs" / "repo"

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

import xml.etree.ElementTree as ET

pom_files = list(AAR_REPO.rglob("flutter_release-*.pom")) if AAR_REPO.is_dir() else []
if len(pom_files) != 1:
    raise SystemExit(f"Expected one Flutter release AAR POM in {AAR_REPO}, found {len(pom_files)}")
pom_root = ET.parse(pom_files[0]).getroot()
def pom_value(name):
    node = pom_root.find(name)
    if node is None:
        node = pom_root.find("{*}" + name)
    return node.text.strip() if node is not None and node.text else None
coordinates = [pom_value("groupId"), pom_value("artifactId"), pom_value("version")]
if not all(coordinates):
    raise SystemExit(f"Unable to read Flutter AAR Maven coordinates from {pom_files[0]}")
aar_dependency = ":".join(coordinates)

root_gradle = NATIVE / "build.gradle"
replace_once(root_gradle, "allprojects {\n    repositories {\n",
             'allprojects {\n    repositories {\n        maven { url "$rootDir/../../flutter_companion_module/build/host/outputs/repo" }\n        maven { url "https://storage.googleapis.com/download.flutter.io" }\n')

app_gradle = NATIVE / "app" / "build.gradle"
replace_once(app_gradle, "dependencies {\n",
             "dependencies {\n    implementation '" + aar_dependency + "'\n")

manifest = NATIVE / "app" / "src" / "main" / "AndroidManifest.xml"
manifest_text = manifest.read_text(encoding="utf-8")
manage_permission = '<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />'
if manage_permission not in manifest_text:
    anchor = '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>'
    if anchor not in manifest_text:
        raise SystemExit("Cannot add All files access permission: manifest anchor missing")
    manifest.write_text(manifest_text.replace(anchor, anchor + "\n    " + manage_permission, 1), encoding="utf-8")
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

import android.app.Activity;
import android.Manifest;
import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import android.provider.DocumentsContract;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.preference.PreferenceManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/** Hosts the Flutter companion and bridges its game-folder and realm settings to Winlator. */
public class WowLKCompanionActivity extends FlutterActivity {
    private static final String CHANNEL = "wow.lk/storage";
    private static final int REQUEST_GAME_TREE = 4019;
    private static final int REQUEST_ALL_FILES_ACCESS = 4021;
    private MethodChannel.Result pendingFolderResult;
    private AtomicBoolean importCancelled;
    private MethodChannel storageChannel;
    private final java.util.concurrent.ExecutorService importerExecutor = Executors.newSingleThreadExecutor();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        MethodChannel channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        storageChannel = channel;
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "openNativeGameLauncher":
                    startActivity(new Intent(this, WowMobileActivity.class).putExtra("wow.lk.AUTO_PLAY", true));
                    result.success(true);
                    break;
                case "openNativeWowSettings":
                    startActivity(new Intent(this, WowSettingsActivity.class));
                    result.success(true);
                    break;
                case "openNativeContainerSettings":
                    startActivity(new Intent(this, ContainerSettingsActivity.class));
                    result.success(true);
                    break;
                case "openNativeControlsEditor":
                    startActivity(new Intent(this, com.winlator.ControlsEditorActivity.class)
                        .putExtra("profile_id", 0));
                    result.success(true);
                    break;
                case "getDeviceInfo":
                    result.success(readBasicDeviceInfo());
                    break;
                case "getSavedGameTreeUri":
                    result.success(getCompanionPreferences().getString("game_tree_uri", null));
                    break;
                case "pickGameFolderTree":
                    if (pendingFolderResult != null) {
                        result.error("IMPORT_BUSY", "A game-folder selection is already being processed.", null);
                        break;
                    }
                    pendingFolderResult = result;
                    if (Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
                        Intent access = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                            Uri.parse("package:" + getPackageName()));
                        startActivityForResult(access, REQUEST_ALL_FILES_ACCESS);
                    } else {
                        launchGameTreePicker();
                    }
                    break;
                case "cancelGameImport":
                    if (importCancelled != null) importCancelled.set(true);
                    result.success(importCancelled != null);
                    break;
                case "getImportedGamePath":
                    result.success(getCompanionPreferences().getString("imported_game_path", null));
                    break;
                case "scanGameTree":
                    result.success(scanGameTree(call.argument("treeUri")));
                    break;
                case "writeRealmlist":
                    result.success(writeRealmlist(call.argument("treeUri"), call.argument("content"), call.argument("localeName")));
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    private void launchGameTreePicker() {
        Intent picker = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        picker.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(picker, REQUEST_GAME_TREE);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != 4020 || pendingFolderResult == null) return;
        if (grantResults.length > 0 && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED) {
            launchGameTreePicker();
        } else {
            MethodChannel.Result callback = pendingFolderResult;
            pendingFolderResult = null;
            callback.error("STORAGE_PERMISSION", "Allow storage access so Winlator can read the original game files without copying them.", null);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_ALL_FILES_ACCESS) {
            if (Build.VERSION.SDK_INT >= 30 && Environment.isExternalStorageManager()) {
                launchGameTreePicker();
            } else if (pendingFolderResult != null) {
                MethodChannel.Result callback = pendingFolderResult;
                pendingFolderResult = null;
                callback.error("ALL_FILES_ACCESS", "Allow WOW LK to manage files so the game engine can read the selected original folder without copying it.", null);
            }
            return;
        }
        if (requestCode != REQUEST_GAME_TREE || pendingFolderResult == null) return;
        final MethodChannel.Result callback = pendingFolderResult;
        pendingFolderResult = null;
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            callback.success(null);
            return;
        }
        final Uri treeUri = data.getData();
        try {
            int offered = data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            int flags = offered & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            if ((flags & Intent.FLAG_GRANT_READ_URI_PERMISSION) == 0) {
                callback.error("TREE_READ_PERMISSION", "Android did not grant read access. Select the main WoW folder and tap Use this folder, then Allow.", null);
                return;
            }
            getContentResolver().takePersistableUriPermission(treeUri, flags);
            boolean persistedRead = false;
            for (android.content.UriPermission permission : getContentResolver().getPersistedUriPermissions()) {
                if (permission.getUri().equals(treeUri) && permission.isReadPermission()) persistedRead = true;
            }
            if (!persistedRead) {
                callback.error("TREE_PERMISSION", "Android did not retain permission for this folder. Please select it again.", null);
                return;
            }
        } catch (SecurityException error) {
            callback.error("TREE_PERMISSION", "Android could not retain access to the selected folder: " + error.getMessage(), null);
            return;
        }
        try {
            Map<String, Object> fileReport = scanGameTree(treeUri.toString());
            if (!Boolean.TRUE.equals(fileReport.get("executableFound")) ||
                !Boolean.TRUE.equals(fileReport.get("dataFolderFound"))) {
                @SuppressWarnings("unchecked")
                ArrayList<String> detected = (ArrayList<String>) fileReport.get("detectedFiles");
                throw new IllegalStateException("Folder access was granted, but the selected folder is not the WoW root. Detected: " +
                    (detected == null || detected.isEmpty() ? "no entries returned by Android" : android.text.TextUtils.join(", ", detected)) +
                    ". Select the folder that directly contains Wow.exe and Data/.");
            }
            File originalGameFolder = WowGameFolderImporter.resolveAndValidateTree(this, treeUri);
            getCompanionPreferences().edit().putString("game_tree_uri", treeUri.toString())
                .putString("imported_game_path", originalGameFolder.getAbsolutePath()).apply();
            PreferenceManager.getDefaultSharedPreferences(this).edit()
                .putString(WowMobileActivity.PREF_GAME_FOLDER, originalGameFolder.getAbsolutePath()).apply();
            Map<String, Object> finished = new HashMap<>();
            finished.put("success", true);
            finished.put("importedPath", originalGameFolder.getAbsolutePath());
            finished.put("linkedOriginal", true);
            storageChannel.invokeMethod("gameImportFinished", finished);
            callback.success(treeUri.toString());
        } catch (Exception error) {
            callback.error("GAME_FOLDER_INVALID",
                error.getMessage() == null ? "Could not access the original WoW folder." : error.getMessage(), null);
        }
    }

    @Override
    protected void onDestroy() {
        if (importCancelled != null) importCancelled.set(true);
        if (pendingFolderResult != null) {
            pendingFolderResult.error("ACTIVITY_CLOSED", "The launcher closed before folder import completed.", null);
            pendingFolderResult = null;
        }
        importerExecutor.shutdown();
        super.onDestroy();
    }

    private SharedPreferences getCompanionPreferences() {
        return getSharedPreferences("wow_lk_companion", Context.MODE_PRIVATE);
    }

    private Map<String, Object> scanGameTree(String rawTreeUri) {
        if (rawTreeUri == null) throw new IllegalArgumentException("No saved WoW folder permission. Select the original game folder again.");
        Uri tree = Uri.parse(rawTreeUri);
        boolean persisted = false;
        for (android.content.UriPermission permission : getContentResolver().getPersistedUriPermissions()) {
            if (permission.getUri().equals(tree) && permission.isReadPermission()) persisted = true;
        }
        if (!persisted) throw new SecurityException("Android no longer grants read access to this WoW folder. Select it again and tap Use this folder and Allow.");

        Map<String, Object> response = new HashMap<>();
        ArrayList<String> detected = new ArrayList<>();
        ArrayList<String> locales = new ArrayList<>();
        ArrayList<String> realmlists = new ArrayList<>();
        ArrayList<String> emptyArchives = new ArrayList<>();
        ArrayList<String> missingCore = new ArrayList<>();
        String rootId = DocumentsContract.getTreeDocumentId(tree);
        ArrayList<Map<String, Object>> rootItems;
        try {
            rootItems = listDocumentChildren(tree, rootId);
        } catch (Exception providerError) {
            if (Build.VERSION.SDK_INT >= 30 && Environment.isExternalStorageManager()) {
                return scanGameTreeDirect(WowGameFolderImporter.resolveAndValidateTree(this, tree));
            }
            throw providerError;
        }
        boolean hasRootExe = false;
        boolean hasRootData = false;
        for (Map<String, Object> entry : rootItems) {
            String entryName = (String) entry.get("name");
            if (entryName.equalsIgnoreCase("Wow.exe") || entryName.equalsIgnoreCase("Wow-64.exe")) hasRootExe = true;
            if (entryName.equalsIgnoreCase("Data") && Boolean.TRUE.equals(entry.get("directory"))) hasRootData = true;
        }
        if ((!hasRootExe || !hasRootData) && Build.VERSION.SDK_INT >= 30 && Environment.isExternalStorageManager()) {
            return scanGameTreeDirect(WowGameFolderImporter.resolveAndValidateTree(this, tree));
        }
        boolean executable = false;
        boolean wtf = false;
        Uri dataFolder = null;
        for (Map<String, Object> item : rootItems) {
            String name = (String) item.get("name");
            boolean dir = (Boolean) item.get("directory");
            if (name.equalsIgnoreCase("Wow.exe") || name.equalsIgnoreCase("Wow-64.exe")) executable = true;
            if (name.equalsIgnoreCase("WTF") && dir) {
                wtf = true;
                detected.add("WTF/");
            }
            if (name.equalsIgnoreCase("Data") && dir) {
                dataFolder = DocumentsContract.buildDocumentUriUsingTree(tree, (String) item.get("id"));
                detected.add("Data/");
            }
            if (name.equalsIgnoreCase("Wow.exe") || name.equalsIgnoreCase("Wow-64.exe")) detected.add(name);
        }
        if (dataFolder == null) throw new IllegalStateException("The selected folder is accessible, but Data/ was not found. Select the main WoW folder containing Wow.exe and Data/.");
        if (!executable) throw new IllegalStateException("Data/ was found, but Wow.exe / Wow-64.exe was not listed at the selected folder root. Select the main WoW folder, not a parent or Data subfolder.");
        int archiveCount = 0;
        long totalBytes = 0;
        java.util.HashSet<String> coreFound = new java.util.HashSet<>();
        ArrayList<Uri> pending = new ArrayList<>();
        ArrayList<String> pendingPaths = new ArrayList<>();
        pending.add(dataFolder);
        pendingPaths.add("Data");
        while (!pending.isEmpty()) {
            Uri parent = pending.remove(0);
            String parentPath = pendingPaths.remove(0);
            for (Map<String, Object> item : listDocumentChildren(tree, DocumentsContract.getDocumentId(parent))) {
                String name = (String) item.get("name");
                boolean dir = (Boolean) item.get("directory");
                String path = parentPath + "/" + name;
                if (dir) {
                    if (parentPath.equals("Data") && name.matches("[A-Za-z]{2}[A-Za-z]{2}")) {
                        locales.add(name);
                        detected.add(path + "/");
                    }
                    if (parentPath.split("/").length < 3) {
                        pending.add(DocumentsContract.buildDocumentUriUsingTree(tree, (String) item.get("id")));
                        pendingPaths.add(path);
                    }
                } else {
                    detected.add(path);
                    if (name.equalsIgnoreCase("realmlist.wtf")) realmlists.add(path);
                    if (name.toLowerCase(java.util.Locale.ROOT).endsWith(".mpq")) {
                        archiveCount++;
                        long size = (Long) item.get("size");
                        totalBytes += Math.max(0L, size);
                        if (size == 0) emptyArchives.add(path);
                        String lower = name.toLowerCase(java.util.Locale.ROOT);
                        if (lower.equals("common.mpq") || lower.equals("common-2.mpq") ||
                            lower.equals("expansion.mpq") || lower.equals("lichking.mpq")) coreFound.add(lower);
                    }
                }
            }
        }
        String[] core = {"common.mpq", "common-2.mpq", "expansion.mpq", "lichking.mpq"};
        for (String name : core) if (!coreFound.contains(name)) missingCore.add(name);
        java.util.Collections.sort(locales);
        java.util.Collections.sort(realmlists);
        java.util.Collections.sort(detected);
        response.put("folderExists", true);
        response.put("executableFound", executable);
        response.put("dataFolderFound", dataFolder != null);
        response.put("wtfFolderFound", wtf);
        response.put("localeFolders", locales);
        response.put("realmlistFiles", realmlists);
        response.put("archiveCount", archiveCount);
        response.put("totalArchiveBytes", totalBytes);
        response.put("emptyArchiveFiles", emptyArchives);
        response.put("missingCoreArchives", missingCore);
        response.put("detectedFiles", detected);
        ArrayList<String> notes = new ArrayList<>();
        if (!executable) notes.add("Wow.exe / Wow-64.exe was not listed in the selected root folder.");
        if (!wtf) notes.add("WTF/ folder was not found in the selected root folder.");
        if (locales.isEmpty()) notes.add("No locale folder such as enUS or enGB was found under Data/.");
        if (realmlists.isEmpty()) notes.add("No realmlist.wtf was found under a locale folder.");
        if (archiveCount == 0) notes.add("No MPQ archives were listed under Data/.");
        response.put("notes", notes);
        return response;
    }

    private Map<String, Object> scanGameTreeDirect(File root) {
        if (root == null || !root.isDirectory()) throw new IllegalStateException("The selected WoW folder is not readable as a normal Android folder path.");
        File[] rootEntries = root.listFiles();
        if (rootEntries == null) throw new SecurityException("Android still blocks direct access to this folder. Enable All files access for WOW LK and select the folder again.");
        Map<String, Object> response = new HashMap<>();
        ArrayList<String> detected = new ArrayList<>();
        ArrayList<String> locales = new ArrayList<>();
        ArrayList<String> realmlists = new ArrayList<>();
        ArrayList<String> emptyArchives = new ArrayList<>();
        ArrayList<String> missingCore = new ArrayList<>();
        boolean executable = false, wtf = false;
        File data = new File(root, "Data");
        for (File item : rootEntries) {
            String name = item.getName();
            if (item.isFile() && (name.equalsIgnoreCase("Wow.exe") || name.equalsIgnoreCase("Wow-64.exe"))) {
                executable = true; detected.add(name);
            }
            if (item.isDirectory() && name.equalsIgnoreCase("WTF")) { wtf = true; detected.add("WTF/"); }
            if (item.isDirectory() && name.equalsIgnoreCase("Data")) detected.add("Data/");
        }
        if (!executable || !data.isDirectory()) throw new IllegalStateException("The selected folder is accessible, but it does not directly contain Wow.exe and Data/. Select the main WoW folder.");
        int archiveCount = 0; long totalBytes = 0;
        java.util.HashSet<String> coreFound = new java.util.HashSet<>();
        java.util.ArrayDeque<File> pending = new java.util.ArrayDeque<>();
        java.util.ArrayDeque<Integer> depths = new java.util.ArrayDeque<>();
        pending.add(data); depths.add(0);
        while (!pending.isEmpty()) {
            File parent = pending.removeFirst(); int depth = depths.removeFirst();
            File[] children = parent.listFiles();
            if (children == null) throw new SecurityException("Cannot read game folder: " + parent.getAbsolutePath());
            for (File item : children) {
                String name = item.getName();
                String relative = root.toPath().relativize(item.toPath()).toString().replace(File.separatorChar, '/');
                if (item.isDirectory()) {
                    if (parent.equals(data) && name.matches("[A-Za-z]{2}[A-Za-z]{2}")) {
                        locales.add(name); detected.add(relative + "/");
                    }
                    if (depth < 2) { pending.addLast(item); depths.addLast(depth + 1); }
                } else {
                    detected.add(relative);
                    if (name.equalsIgnoreCase("realmlist.wtf")) realmlists.add(relative);
                    if (name.toLowerCase(java.util.Locale.ROOT).endsWith(".mpq")) {
                        archiveCount++; totalBytes += item.length();
                        if (item.length() == 0) emptyArchives.add(relative);
                        String lower = name.toLowerCase(java.util.Locale.ROOT);
                        if (lower.equals("common.mpq") || lower.equals("common-2.mpq") ||
                            lower.equals("expansion.mpq") || lower.equals("lichking.mpq")) coreFound.add(lower);
                    }
                }
            }
        }
        for (String core : new String[]{"common.mpq","common-2.mpq","expansion.mpq","lichking.mpq"}) if (!coreFound.contains(core)) missingCore.add(core);
        java.util.Collections.sort(locales); java.util.Collections.sort(realmlists); java.util.Collections.sort(detected);
        response.put("folderExists", true); response.put("executableFound", true); response.put("dataFolderFound", true);
        response.put("wtfFolderFound", wtf); response.put("localeFolders", locales); response.put("realmlistFiles", realmlists);
        response.put("archiveCount", archiveCount); response.put("totalArchiveBytes", totalBytes);
        response.put("emptyArchiveFiles", emptyArchives); response.put("missingCoreArchives", missingCore);
        response.put("detectedFiles", detected);
        ArrayList<String> notes = new ArrayList<>();
        if (!wtf) notes.add("WTF/ folder was not found in the selected root folder.");
        if (locales.isEmpty()) notes.add("No locale folder such as enUS or enGB was found under Data/.");
        if (realmlists.isEmpty()) notes.add("No realmlist.wtf was found under a locale folder.");
        if (archiveCount == 0) notes.add("No MPQ archives were listed under Data/.");
        response.put("notes", notes);
        response.put("scanMethod", "direct-file-access");
        return response;
    }

    private ArrayList<Map<String, Object>> listDocumentChildren(Uri tree, String parentId) {
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId);
        String[] columns = {
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE
        };
        Cursor cursor = getContentResolver().query(children, columns, null, null, null);
        if (cursor == null) throw new IllegalStateException("Android's folder provider did not return a file listing. Re-select the WoW folder and allow access.");
        ArrayList<Map<String, Object>> result = new ArrayList<>();
        try (Cursor c = cursor) {
            int idCol = c.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID);
            int nameCol = c.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME);
            int mimeCol = c.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE);
            int sizeCol = c.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE);
            while (c.moveToNext()) {
                String name = c.getString(nameCol);
                String mime = c.getString(mimeCol);
                String safeName = name == null ? "" : name;
                boolean looksLikeKnownDirectory = safeName.equalsIgnoreCase("Data") ||
                    safeName.equalsIgnoreCase("WTF") ||
                    safeName.matches("[A-Za-z]{2}[A-Za-z]{2}");
                // OEM document providers often return null, blank, or octet-stream
                // MIME types for real directories. Confirm those candidates by
                // successfully querying their child document list.
                boolean directory = DocumentsContract.Document.MIME_TYPE_DIR.equals(mime);
                if (!directory && looksLikeKnownDirectory) {
                    boolean providerAmbiguous = mime == null || mime.isEmpty() ||
                        "application/octet-stream".equals(mime);
                    if (providerAmbiguous) {
                        try {
                            Uri candidateChildren = DocumentsContract.buildChildDocumentsUriUsingTree(
                                tree, c.getString(idCol));
                            Cursor probe = getContentResolver().query(candidateChildren,
                                new String[]{DocumentsContract.Document.COLUMN_DOCUMENT_ID}, null, null, null);
                            if (probe != null) {
                                probe.close();
                                directory = true;
                            }
                        } catch (Exception ignored) { }
                    }
                }
                Map<String, Object> item = new HashMap<>();
                item.put("id", c.getString(idCol));
                item.put("name", name == null ? "" : name);
                item.put("directory", directory);
                item.put("size", sizeCol >= 0 && !c.isNull(sizeCol) ? c.getLong(sizeCol) : 0L);
                result.add(item);
            }
        }
        return result;
    }

    private boolean writeRealmlist(String rawTreeUri, String content, String localeName) {
        if (rawTreeUri == null || content == null || localeName == null || !localeName.matches("[A-Za-z]{2}[A-Za-z]{2}")) return false;
        try {
            Uri tree = Uri.parse(rawTreeUri);
            Uri data = findChild(tree, DocumentsContract.getTreeDocumentId(tree), "Data", true);
            if (data == null) return false;
            Uri locale = findChild(tree, DocumentsContract.getDocumentId(data), localeName, true);
            if (locale == null) return false;
            Uri realmlist = findChild(tree, DocumentsContract.getDocumentId(locale), "realmlist.wtf", false);
            if (realmlist == null) realmlist = DocumentsContract.createDocument(getContentResolver(), locale, "text/plain", "realmlist.wtf");
            if (realmlist == null) return false;
            try (OutputStream output = getContentResolver().openOutputStream(realmlist, "wt")) {
                if (output == null) return false;
                output.write(content.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                output.flush();
            }
            String importedPath = getCompanionPreferences().getString("imported_game_path", null);
            if (importedPath != null) {
                File localFile = new File(new File(new File(importedPath, "Data"), localeName), "realmlist.wtf");
                File parent = localFile.getParentFile();
                if (parent != null && parent.isDirectory()) {
                    try (FileOutputStream output = new FileOutputStream(localFile, false)) {
                        output.write(content.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                        output.getFD().sync();
                    }
                }
            }
            return true;
        } catch (Exception error) {
            return false;
        }
    }

    private Uri findChild(Uri tree, String parentId, String name, boolean directory) {
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId);
        String[] columns = {DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE};
        try (Cursor cursor = getContentResolver().query(children, columns, null, null, null)) {
            if (cursor == null) return null;
            int idCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID);
            int nameCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME);
            int mimeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE);
            while (cursor.moveToNext()) {
                String childName = cursor.getString(nameCol);
                String mime = cursor.getString(mimeCol);
                boolean knownDirectory = childName != null && (childName.equalsIgnoreCase("Data") ||
                    childName.equalsIgnoreCase("WTF") || childName.matches("[A-Za-z]{2}[A-Za-z]{2}"));
                boolean isDirectory = DocumentsContract.Document.MIME_TYPE_DIR.equals(mime) ||
                    (directory && knownDirectory && (mime == null || mime.isEmpty() || "application/octet-stream".equals(mime)));
                if (name.equalsIgnoreCase(childName) && isDirectory == directory) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(idCol));
                }
            }
        } catch (Exception ignored) {}
        return null;
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
        info.put("cpuModel", Build.VERSION.SDK_INT >= 31 ? Build.SOC_MODEL : Build.HARDWARE);
        info.put("cpuArchitecture", Build.SUPPORTED_ABIS.length > 0 ? Build.SUPPORTED_ABIS[0] : "Unknown");
        info.put("androidVersion", Build.VERSION.RELEASE);
        info.put("sdkInt", Build.VERSION.SDK_INT);
        info.put("cpuCores", Runtime.getRuntime().availableProcessors());
        info.put("supportedAbis", java.util.Arrays.asList(Build.SUPPORTED_ABIS));
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
}''', encoding="utf-8")

print("Flutter companion integration patch applied.")
print("Launcher: Flutter companion Activity; native WoW launcher remains in the same APK.")
print("Integrated bridges: SAF game-folder linking, Realm Manager realmlist writes, device diagnostics, and native launcher.")
