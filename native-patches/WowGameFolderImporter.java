package com.winlator.wowmobile;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Copies a user-selected SAF tree into app-owned storage so Winlator can mount
 * it as a normal filesystem drive. The source tree is never modified.
 */
public final class WowGameFolderImporter {
    public interface Listener {
        void onProgress(String currentPath, long copiedBytes, long totalBytes);
    }

    private static final String[] CHILD_COLUMNS = {
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        OpenableColumns.SIZE
    };

    private WowGameFolderImporter() {}

    public static File importTree(Context context, Uri treeUri, AtomicBoolean cancelled,
                                  Listener listener) throws IOException {
        ContentResolver resolver = context.getContentResolver();
        String rootId = DocumentsContract.getTreeDocumentId(treeUri);
        Uri rootUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId);

        boolean hasExe = false;
        boolean hasData = false;
        long totalBytes = 0L;
        try (Cursor cursor = resolver.query(rootUri, CHILD_COLUMNS, null, null, null)) {
            if (cursor == null) throw new IOException("The selected folder cannot be read.");
            int nameCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME);
            int mimeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE);
            int sizeCol = cursor.getColumnIndex(OpenableColumns.SIZE);
            while (cursor.moveToNext()) {
                String name = cursor.getString(nameCol);
                String mime = cursor.getString(mimeCol);
                if ("Wow.exe".equalsIgnoreCase(name) && !DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)) hasExe = true;
                if ("Data".equalsIgnoreCase(name) && DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)) hasData = true;
                if (sizeCol >= 0 && !cursor.isNull(sizeCol)) totalBytes += Math.max(0L, cursor.getLong(sizeCol));
            }
        }
        if (!hasExe || !hasData) throw new IOException("Select the main WoW folder containing Wow.exe and Data/.");

        File base = context.getExternalFilesDir("wow-client");
        if (base == null) base = new File(context.getFilesDir(), "wow-client");
        if (!base.exists() && !base.mkdirs()) throw new IOException("Cannot create app storage for the game.");
        long available = base.getUsableSpace();
        if (totalBytes > 0 && available < totalBytes + Math.max(256L * 1024L * 1024L, totalBytes / 20L)) {
            throw new IOException("Not enough free space. Free space: " + (available / (1024L * 1024L)) + " MB.");
        }

        File temp = new File(base, "Importing");
        File destination = new File(base, "WoW");
        File backup = new File(base, "WoW.previous");
        deleteRecursively(temp);
        if (!temp.mkdirs()) throw new IOException("Cannot prepare the import folder.");

        try {
            copyDirectory(context, treeUri, rootId, temp, cancelled, listener, new long[]{0L}, totalBytes, "");
            File exe = new File(temp, "Wow.exe");
            File data = new File(temp, "Data");
            if (!exe.isFile() || !data.isDirectory()) throw new IOException("The copied game folder failed validation.");

            deleteRecursively(backup);
            if (destination.exists() && !destination.renameTo(backup)) throw new IOException("Cannot safely replace the previous imported game.");
            if (!temp.renameTo(destination)) {
                if (backup.exists()) backup.renameTo(destination);
                throw new IOException("Cannot finalize the imported game folder.");
            }
            deleteRecursively(backup);
            return destination;
        } catch (IOException | RuntimeException error) {
            deleteRecursively(temp);
            throw error;
        }
    }

    private static void copyDirectory(Context context, Uri treeUri, String parentId, File target,
                                      AtomicBoolean cancelled, Listener listener, long[] copied,
                                      long total, String relative) throws IOException {
        ContentResolver resolver = context.getContentResolver();
        Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId);
        try (Cursor cursor = resolver.query(childrenUri, CHILD_COLUMNS, null, null, null)) {
            if (cursor == null) throw new IOException("Cannot list a folder in the selected game tree: " + relative);
            int idCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID);
            int nameCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME);
            int mimeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE);
            while (cursor.moveToNext()) {
                if (cancelled.get()) throw new IOException("Import cancelled.");
                String id = cursor.getString(idCol);
                String name = cursor.getString(nameCol);
                String mime = cursor.getString(mimeCol);
                if (name == null || name.isEmpty() || name.equals(".") || name.equals("..") || name.contains("/") || name.contains("\\")) {
                    throw new IOException("The selected folder contains an unsupported file name.");
                }
                File child = new File(target, name);
                String canonical = child.getCanonicalPath();
                if (!canonical.startsWith(target.getCanonicalPath() + File.separator)) throw new IOException("Unsafe path in selected folder.");
                String childRelative = relative.isEmpty() ? name : relative + "/" + name;
                if (DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)) {
                    if (!child.exists() && !child.mkdir()) throw new IOException("Cannot create folder: " + childRelative);
                    copyDirectory(context, treeUri, id, child, cancelled, listener, copied, total, childRelative);
                } else {
                    Uri fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id);
                    try (InputStream input = resolver.openInputStream(fileUri)) {
                        if (input == null) throw new IOException("Cannot read file: " + childRelative);
                        try (FileOutputStream output = new FileOutputStream(child)) {
                            byte[] buffer = new byte[1024 * 1024];
                            int read;
                            while ((read = input.read(buffer)) != -1) {
                                if (cancelled.get()) throw new IOException("Import cancelled.");
                                output.write(buffer, 0, read);
                                copied[0] += read;
                                if (listener != null) listener.onProgress(childRelative, copied[0], total);
                            }
                            output.getFD().sync();
                        }
                    }
                }
            }
        }
    }

    private static void deleteRecursively(File file) {
        if (file == null || !file.exists()) return;
        File[] children = file.listFiles();
        if (children != null) for (File child : children) deleteRecursively(child);
        file.delete();
    }
}
