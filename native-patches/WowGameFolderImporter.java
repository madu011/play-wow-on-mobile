package com.winlator.wowmobile;

import android.content.ContentResolver;
import android.content.Context;
import android.content.UriPermission;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.provider.DocumentsContract;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Resolves and validates the original shared-storage WoW folder.
 * It deliberately does not copy, stage, extract, or duplicate game files.
 *
 * The SAF tree is used for validation because a persisted document permission
 * does not automatically imply that java.io.File can read the same path under
 * Android scoped storage. Winlator still receives the mapped filesystem path.
 */
public final class WowGameFolderImporter {
    private static final String EXTERNAL_STORAGE_AUTHORITY =
            "com.android.externalstorage.documents";
    private static final String[] CHILD_COLUMNS = {
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
    };

    private WowGameFolderImporter() {}

    private static final class Entry {
        final Uri uri;
        final String name;
        final String mime;

        Entry(Uri uri, String name, String mime) {
            this.uri = uri;
            this.name = name;
            this.mime = mime;
        }

        boolean isDirectory() {
            return DocumentsContract.Document.MIME_TYPE_DIR.equals(mime);
        }
    }

    public static File resolveAndValidateTree(Context context, Uri treeUri) throws IOException {
        if (treeUri == null || !EXTERNAL_STORAGE_AUTHORITY.equals(treeUri.getAuthority())) {
            throw new IOException(
                    "Choose the original WoW folder from this device's internal storage or an accessible SD card. " +
                    "Cloud/document providers cannot be mounted by Winlator without copying.");
        }

        requirePersistedTreePermission(context, treeUri);

        final String documentId;
        try {
            documentId = DocumentsContract.getTreeDocumentId(treeUri);
        } catch (Exception error) {
            throw new IOException("Android could not identify the selected game folder.", error);
        }

        int separator = documentId.indexOf(':');
        if (separator <= 0) {
            throw new IOException("The selected folder is not a directly accessible storage location.");
        }

        String volume = documentId.substring(0, separator);
        String relativePath = documentId.substring(separator + 1);
        if (relativePath.startsWith("/") || relativePath.contains("\\\\")) {
            throw new IOException("The selected folder path is invalid.");
        }
        for (String part : relativePath.split("/")) {
            if ("..".equals(part) || ".".equals(part)) {
                throw new IOException("The selected folder path is invalid.");
            }
        }

        File volumeRoot = "primary".equalsIgnoreCase(volume)
                ? Environment.getExternalStorageDirectory()
                : new File("/storage", volume);
        File canonicalRoot = volumeRoot.getCanonicalFile();
        File selected = relativePath.isEmpty()
                ? canonicalRoot
                : new File(canonicalRoot, relativePath);
        File canonicalSelected = selected.getCanonicalFile();

        if (!canonicalSelected.equals(canonicalRoot) &&
                !canonicalSelected.getPath().startsWith(canonicalRoot.getPath() + File.separator)) {
            throw new IOException("The selected folder is outside the storage volume.");
        }

        validateGameTree(context, treeUri, documentId);
        return canonicalSelected;
    }

    private static void requirePersistedTreePermission(Context context, Uri treeUri)
            throws IOException {
        boolean readable = false;
        boolean writable = false;
        for (UriPermission permission : context.getContentResolver().getPersistedUriPermissions()) {
            if (treeUri.equals(permission.getUri())) {
                readable |= permission.isReadPermission();
                writable |= permission.isWritePermission();
            }
        }
        if (!readable || !writable) {
            throw new IOException(
                    "Android has not saved both read and write access for this folder. " +
                    "Select the WoW folder again and confirm the access prompt.");
        }
    }

    private static void validateGameTree(Context context, Uri treeUri, String rootId)
            throws IOException {
        List<Entry> root = children(context, treeUri, rootId);
        Entry executable = findFile(root, "Wow.exe");
        if (executable == null) executable = findFile(root, "Wow-64.exe");
        if (executable == null) {
            throw new IOException(
                    "Wow.exe was not found in the selected folder. Select the main WoW folder, not its parent or Data folder.");
        }
        probeReadable(context.getContentResolver(), executable,
                "The WoW executable cannot be read through Android folder access.");

        Entry data = findDirectory(root, "Data");
        if (data == null) {
            throw new IOException("The selected folder does not contain a readable Data/ directory.");
        }

        List<Entry> dataEntries = children(context, treeUri,
                DocumentsContract.getDocumentId(data.uri));
        String[] requiredArchives = {"common.MPQ", "expansion.MPQ", "lichking.MPQ"};
        for (String archiveName : requiredArchives) {
            Entry archive = findFile(dataEntries, archiveName);
            if (archive == null) {
                throw new IOException("Required game archive is missing from Data/: " + archiveName);
            }
            probeReadable(context.getContentResolver(), archive,
                    "Android cannot read the game archive: Data/" + archiveName);
        }

        boolean validLocale = false;
        for (Entry entry : dataEntries) {
            if (!entry.isDirectory() || !isLocaleFolder(entry.name)) continue;
            List<Entry> localeEntries = children(context, treeUri,
                    DocumentsContract.getDocumentId(entry.uri));
            for (Entry localeArchive : localeEntries) {
                if (localeArchive.isDirectory() ||
                        !localeArchive.name.toLowerCase(Locale.ROOT).endsWith(".mpq")) {
                    continue;
                }
                probeReadable(context.getContentResolver(), localeArchive,
                        "Android cannot read a locale archive in Data/" + entry.name + "/.");
                validLocale = true;
                break;
            }
            if (validLocale) break;
        }
        if (!validLocale) {
            throw new IOException(
                    "No locale folder containing a readable MPQ archive was found in Data/. " +
                    "Check that the WoW client is complete.");
        }
    }

    private static boolean isLocaleFolder(String name) {
        return name != null && name.length() == 4 &&
                Character.isLowerCase(name.charAt(0)) &&
                Character.isLowerCase(name.charAt(1)) &&
                Character.isUpperCase(name.charAt(2)) &&
                Character.isUpperCase(name.charAt(3));
    }

    private static List<Entry> children(Context context, Uri treeUri, String parentId)
            throws IOException {
        Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId);
        List<Entry> result = new ArrayList<>();
        try (Cursor cursor = context.getContentResolver().query(
                childrenUri, CHILD_COLUMNS, null, null, null)) {
            if (cursor == null) {
                throw new IOException("Android could not list the selected WoW folder.");
            }
            int idColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID);
            int nameColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME);
            int mimeColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE);
            if (idColumn < 0 || nameColumn < 0 || mimeColumn < 0) {
                throw new IOException("The selected storage provider returned incomplete folder information.");
            }
            while (cursor.moveToNext()) {
                String id = cursor.getString(idColumn);
                String name = cursor.getString(nameColumn);
                String mime = cursor.getString(mimeColumn);
                if (id == null || name == null) continue;
                Uri childUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id);
                result.add(new Entry(childUri, name, mime == null ? "" : mime));
            }
        } catch (SecurityException error) {
            throw new IOException("Android denied access while checking the selected WoW folder.", error);
        }
        return result;
    }

    private static Entry findFile(List<Entry> entries, String name) {
        for (Entry entry : entries) {
            if (!entry.isDirectory() && entry.name.equalsIgnoreCase(name)) return entry;
        }
        return null;
    }

    private static Entry findDirectory(List<Entry> entries, String name) {
        for (Entry entry : entries) {
            if (entry.isDirectory() && entry.name.equalsIgnoreCase(name)) return entry;
        }
        return null;
    }

    private static void probeReadable(ContentResolver resolver, Entry entry, String message)
            throws IOException {
        try (InputStream input = resolver.openInputStream(entry.uri)) {
            if (input == null || input.read() < 0) throw new IOException(message);
        } catch (SecurityException | IllegalArgumentException error) {
            throw new IOException(message, error);
        }
    }
}
