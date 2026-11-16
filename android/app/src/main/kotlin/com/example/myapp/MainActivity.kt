package com.example.myapp

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import android.provider.DocumentsContract
import android.database.Cursor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "wow.lk/storage"
    private val prefsName = "wow_lk_storage"
    private var pendingPickerResult: MethodChannel.Result? = null
    private val treePickerRequestCode = 7412

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    @Deprecated("Deprecated in Android API; retained for compatibility with FlutterActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != treePickerRequestCode) return
        val result = pendingPickerResult
        pendingPickerResult = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) { result?.success(null); return }
        try {
            val flags = (data?.flags ?: 0) and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, flags)
            getSharedPreferences(prefsName, MODE_PRIVATE).edit().putString("game_tree_uri", uri.toString()).apply()
            result?.success(uri.toString())
        } catch (e: Exception) { result?.error("TREE_PERMISSION", e.message, null) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> result.success(getDeviceInfo())
                    "pickGameFolderTree" -> {
                        if (pendingPickerResult != null) {
                            result.error("PICKER_BUSY", "Folder picker is already open.", null)
                        } else {
                            pendingPickerResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            }
                            startActivityForResult(intent, treePickerRequestCode)
                        }
                    }
                    "getSavedGameTreeUri" -> result.success(
                        getSharedPreferences(prefsName, MODE_PRIVATE).getString("game_tree_uri", null)
                    )
                    "scanGameTree" -> {
                        val uri = call.argument<String>("treeUri")
                        if (uri.isNullOrBlank()) result.error("NO_TREE", "Game folder access is missing.", null)
                        else try { result.success(scanTree(Uri.parse(uri))) }
                        catch (e: Exception) { result.error("SCAN_FAILED", e.message, null) }
                    }
                    "writeRealmlist" -> {
                        val uri = call.argument<String>("treeUri")
                        val content = call.argument<String>("content") ?: ""
                        val localeName = call.argument<String>("localeName")
                        if (uri.isNullOrBlank()) result.error("NO_TREE", "Game folder access is missing.", null)
                        else try { result.success(writeRealm(Uri.parse(uri), content, localeName)) }
                        catch (e: Exception) { result.error("WRITE_FAILED", e.message, null) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getDeviceInfo(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memory)
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.getRealMetrics(metrics)
        val packageManager = packageManager
        val hasVulkan = packageManager.hasSystemFeature("android.hardware.vulkan.level") ||
            packageManager.hasSystemFeature("android.hardware.vulkan.version")
        val gles = packageManager.getSystemAvailableFeatures()
            .firstOrNull { it.name == null }?.reqGlEsVersion ?: 0
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "cpuCores" to Runtime.getRuntime().availableProcessors(),
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "totalRamMb" to (memory.totalMem / (1024L * 1024L)).toInt(),
            "availableRamMb" to (memory.availMem / (1024L * 1024L)).toInt(),
            "screenResolution" to "${metrics.widthPixels} × ${metrics.heightPixels}",
            "densityDpi" to metrics.densityDpi,
            "graphicsApi" to if (hasVulkan) "Vulkan feature + OpenGL ES ${gles.toString(16)}" else "OpenGL ES ${gles.toString(16)} (Vulkan not reported)"
        )
    }

    private data class Entry(val uri: Uri, val name: String, val mime: String, val size: Long)

    private fun children(parent: Uri): List<Entry> {
        val id = DocumentsContract.getDocumentId(parent)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(parent, id)
        val out = mutableListOf<Entry>()
        contentResolver.query(
            childrenUri,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE),
            null, null, null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val childId = cursor.getString(0)
                val name = cursor.getString(1) ?: ""
                val mime = cursor.getString(2) ?: ""
                val sizeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                val size = if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) cursor.getLong(sizeIndex) else 0L
                out.add(Entry(DocumentsContract.buildDocumentUriUsingTree(parent, childId), name, mime, size))
            }
        }
        return out
    }

    private fun scanTree(tree: Uri): Map<String, Any> {
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val rootEntries = children(rootUri)
        val exe = rootEntries.any { it.name.equals("wow.exe", true) || it.name.equals("wow-64.exe", true) }
        val data = rootEntries.firstOrNull { it.name.equals("Data", true) && it.mime == DocumentsContract.Document.MIME_TYPE_DIR }
        val locales = mutableSetOf<String>()
        val realmlists = mutableListOf<String>()
        val mpqs = mutableListOf<String>()
        val empty = mutableListOf<String>()
        var totalBytes = 0L
        if (data != null) {
            fun walk(parent: Uri, prefix: String, depth: Int) {
                if (depth > 12) return
                for (entry in children(parent)) {
                    val relative = if (prefix.isEmpty()) entry.name else "$prefix/${entry.name}"
                    if (entry.mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        if (prefix.isEmpty() && entry.name.length == 4 && entry.name.substring(0,2).all { it.isLetter() && it.isLowerCase() } &&
                            entry.name.substring(2).all { it.isLetter() } && entry.name.substring(2).all { it.isUpperCase() }) {
                            locales.add(entry.name)
                        }
                        walk(entry.uri, relative, depth + 1)
                    } else {
                        if (entry.name.equals("realmlist.wtf", true) && relative.contains("/")) {
                            val locale = relative.substringBefore("/")
                            if (locale.length == 4) realmlists.add(relative)
                        }
                        if (entry.name.endsWith(".mpq", true)) {
                            mpqs.add(relative)
                            totalBytes += entry.size
                            if (entry.size == 0L) empty.add(relative)
                        }
                    }
                }
            }
            walk(data.uri, "", 0)
        }
        val core = listOf("common.mpq", "common-2.mpq", "expansion.mpq", "lichking.mpq")
        val found = mpqs.map { it.substringAfterLast("/").lowercase() }.toSet()
        return mapOf(
            "folderExists" to true,
            "executableFound" to exe,
            "dataFolderFound" to (data != null),
            "localeFolders" to locales.sorted(),
            "realmlistFiles" to realmlists.sorted(),
            "archiveCount" to mpqs.size,
            "emptyArchiveFiles" to empty,
            "missingCoreArchives" to core.filter { !found.contains(it) },
            "totalArchiveBytes" to totalBytes,
            "notes" to if (data == null) listOf("Data folder not found or cannot be read through Android folder access.") else emptyList<String>(),
            "mpqPaths" to mpqs
        )
    }

    private fun writeRealm(tree: Uri, content: String, requestedLocale: String?): Boolean {
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val data = children(rootUri).firstOrNull {
            it.name.equals("Data", true) && it.mime == DocumentsContract.Document.MIME_TYPE_DIR
        } ?: return false
        val localeFolders = children(data.uri).filter {
            it.mime == DocumentsContract.Document.MIME_TYPE_DIR &&
                it.name.length == 4 &&
                it.name.substring(0, 2).all { c -> c.isLetter() && c.isLowerCase() } &&
                it.name.substring(2).all { c -> c.isLetter() && c.isUpperCase() }
        }
        if (localeFolders.isEmpty()) return false
        val locale = if (requestedLocale.isNullOrBlank()) {
            if (localeFolders.size != 1) throw IllegalStateException("Multiple locale folders found. Select the game language folder first.")
            localeFolders.first()
        } else {
            localeFolders.firstOrNull { it.name == requestedLocale }
                ?: throw IllegalArgumentException("Selected locale folder was not found in Data/.")
        }
        val existing = children(locale.uri).firstOrNull { it.name.equals("realmlist.wtf", true) }
        val target = if (existing != null) existing.uri else {
            DocumentsContract.createDocument(contentResolver, locale.uri, "text/plain", "realmlist.wtf")
                ?: throw IllegalStateException("Android could not create realmlist.wtf in ${locale.name}.")
        }
        contentResolver.openOutputStream(target, "wt")?.bufferedWriter(Charsets.UTF_8)?.use { it.write(content) }
            ?: throw IllegalStateException("Android could not open realmlist.wtf for writing.")
        return true
    }
}
