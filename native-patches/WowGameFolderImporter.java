package com.winlator.wowmobile;

import android.content.Context;
import android.net.Uri;
import android.os.Environment;
import android.provider.DocumentsContract;

import java.io.File;
import java.io.IOException;

/**
 * Resolves and validates the original shared-storage WoW folder.
 * It deliberately does not copy, stage, extract, or duplicate game files.
 */
public final class WowGameFolderImporter {
    private WowGameFolderImporter() {}

    public static File resolveAndValidateTree(Context context, Uri treeUri) throws IOException {
        if (treeUri == null || !"com.android.externalstorage.documents".equals(treeUri.getAuthority())) {
            throw new IOException("Choose the original WoW folder from this device's internal storage or an accessible SD card. Cloud/document providers cannot be mounted by Winlator without copying.");
        }

        final String documentId;
        try {
            documentId = DocumentsContract.getTreeDocumentId(treeUri);
        } catch (Exception error) {
            throw new IOException("Android could not identify the selected game folder.", error);
        }
        int separator = documentId.indexOf(':');
        if (separator <= 0) throw new IOException("The selected folder is not a directly accessible storage location.");

        String volume = documentId.substring(0, separator);
        String relativePath = documentId.substring(separator + 1);
        if (relativePath.startsWith("/") || relativePath.contains("\\")) {
            throw new IOException("The selected folder path is invalid.");
        }
        for (String part : relativePath.split("/")) {
            if ("..".equals(part) || ".".equals(part)) throw new IOException("The selected folder path is invalid.");
        }

        File volumeRoot;
        if ("primary".equalsIgnoreCase(volume)) {
            volumeRoot = Environment.getExternalStorageDirectory();
        } else {
            volumeRoot = new File("/storage", volume);
        }
        File selected = relativePath.isEmpty() ? volumeRoot : new File(volumeRoot, relativePath);
        File canonicalRoot = volumeRoot.getCanonicalFile();
        File canonicalSelected = selected.getCanonicalFile();
        if (!canonicalSelected.equals(canonicalRoot) &&
            !canonicalSelected.getPath().startsWith(canonicalRoot.getPath() + File.separator)) {
            throw new IOException("The selected folder is outside the storage volume.");
        }
        if (!canonicalSelected.isDirectory() || !canonicalSelected.canRead()) {
            throw new IOException("The original game folder is not readable by WOW LK. Check Android storage permission.");
        }

        File exe = new File(canonicalSelected, "Wow.exe");
        File data = new File(canonicalSelected, "Data");
        if (!exe.isFile() || !exe.canRead() || !data.isDirectory() || !data.canRead()) {
            throw new IOException("Select the main WoW folder containing readable Wow.exe and Data/ files.");
        }
        requireReadableFile(new File(data, "common.MPQ"), "Data/common.MPQ");
        requireReadableFile(new File(data, "expansion.MPQ"), "Data/expansion.MPQ");
        requireReadableFile(new File(data, "lichking.MPQ"), "Data/lichking.MPQ");

        File[] dataEntries = data.listFiles();
        if (dataEntries == null || dataEntries.length == 0) {
            throw new IOException("The Data folder is empty or cannot be read.");
        }
        boolean hasLocaleArchive = false;
        for (File entry : dataEntries) {
            if (!entry.isDirectory() || !entry.getName().matches("(?i)[a-z]{4}")) continue;
            File localeArchive = new File(entry, "locale.MPQ");
            if (localeArchive.isFile() && localeArchive.length() > 0 && localeArchive.canRead()) {
                hasLocaleArchive = true;
                break;
            }
        }
        if (!hasLocaleArchive) {
            throw new IOException("No valid locale folder with locale.MPQ was found under Data/. Check that the WoW client download is complete.");
        }
        return canonicalSelected;
    }

    private static void requireReadableFile(File file, String relativePath) throws IOException {
        if (!file.isFile() || file.length() <= 0 || !file.canRead()) {
            throw new IOException("Required WoW game file is missing, empty, or unreadable: " + relativePath);
        }
    }
}
