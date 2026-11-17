package com.example.myapp

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
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
            if (flags and Intent.FLAG_GRANT_READ_URI_PERMISSION == 0 ||
                flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION == 0) {
                throw SecurityException("Android did not grant both read and write access. In the folder picker, select the main WoW folder and tap Use this folder, then confirm Allow.")
            }
            contentResolver.takePersistableUriPermission(uri, flags)
            // Confirm that the persisted permission is really available before saving it.
            val persisted = contentResolver.persistedUriPermissions.any {
                it.uri == uri && it.isReadPermission && it.isWritePermission
            }
            if (!persisted) throw SecurityException("Android could not keep read/write permission for this folder. Please select the folder again.")
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
        val features = packageManager.getSystemAvailableFeatures()
        val gles = features.firstOrNull { it.name == null }?.reqGlEsVersion ?: 0
        val vulkanVersionRaw = features.firstOrNull { it.name == "android.hardware.vulkan.version" }?.version ?: 0
        val vulkanLevel = features.firstOrNull { it.name == "android.hardware.vulkan.level" }?.version ?: 0
        val glInfo = readGlInfo()
        val vulkanVersion = if (vulkanVersionRaw > 0) {
            "${vulkanVersionRaw shr 22}.${(vulkanVersionRaw shr 12) and 0x3ff}.${vulkanVersionRaw and 0xfff}"
        } else "Not reported by Android"
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
            "graphicsApi" to "OpenGL ES feature 0x${gles.toString(16)}",
            "gpuVendor" to (glInfo["vendor"] ?: "Unavailable"),
            "gpuRenderer" to (glInfo["renderer"] ?: "Unavailable"),
            "openGlVersion" to (glInfo["version"] ?: "Unavailable"),
            "vulkanVersion" to vulkanVersion,
            "vulkanLevel" to if (vulkanLevel > 0) vulkanLevel.toString() else "Not reported by Android"
        )
    }

    private fun readGlInfo(): Map<String, String> {
        var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
        var surface: EGLSurface = EGL14.EGL_NO_SURFACE
        var context: EGLContext = EGL14.EGL_NO_CONTEXT
        try {
            display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (display == EGL14.EGL_NO_DISPLAY) return emptyMap()
            val versions = IntArray(2)
            if (!EGL14.eglInitialize(display, versions, 0, versions, 1)) return emptyMap()
            val configAttrs = intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, 4,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val count = IntArray(1)
            if (!EGL14.eglChooseConfig(display, configAttrs, 0, configs, 0, 1, count, 0) || count[0] == 0) return emptyMap()
            val config = configs[0] ?: return emptyMap()
            surface = EGL14.eglCreatePbufferSurface(display, config,
                intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
            if (surface == EGL14.EGL_NO_SURFACE) return emptyMap()
            context = EGL14.eglCreateContext(display, config, EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
            if (context == EGL14.EGL_NO_CONTEXT) return emptyMap()
            if (!EGL14.eglMakeCurrent(display, surface, surface, context)) return emptyMap()
            val vendor = GLES20.glGetString(GLES20.GL_VENDOR)
            val renderer = GLES20.glGetString(GLES20.GL_RENDERER)
            val version = GLES20.glGetString(GLES20.GL_VERSION)
            return mapOf(
                "vendor" to (vendor ?: "Unknown"),
                "renderer" to (renderer ?: "Unknown"),
                "version" to (version ?: "Unknown")
            )
        } catch (_: Exception) {
            return emptyMap()
        } finally {
            if (display != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
                if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context)
                EGL14.eglTerminate(display)
            }
        }
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
        // Verify persisted SAF permission on every scan; stale URI strings must not look like access.
        val hasRead = contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission
        }
        if (!hasRead) throw SecurityException("Saved folder permission has expired. Tap GRANT READ / WRITE ACCESS and select the WoW folder again.")
        val rootEntries = children(rootUri)
        val exe = rootEntries.any { it.name.equals("wow.exe", true) || it.name.equals("wow-64.exe", true) }
        val detectedFiles = rootEntries.map { it.name }.toMutableList()
        // Some OEM document providers return an empty or generic MIME type for directories.
        val data = rootEntries.firstOrNull {
            it.name.equals("Data", true) &&
                (it.mime == DocumentsContract.Document.MIME_TYPE_DIR || it.mime.isBlank() ||
                 it.mime == "application/octet-stream")
        }
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
                    val looksLikeLocale = prefix.isEmpty() && entry.name.length == 4 &&
                        entry.name.substring(0, 2).all { it.isLetter() && it.isLowerCase() } &&
                        entry.name.substring(2).all { it.isLetter() && it.isUpperCase() }
                    val isDirectory = entry.mime == DocumentsContract.Document.MIME_TYPE_DIR ||
                        entry.mime.isBlank() || entry.mime == "application/octet-stream" || looksLikeLocale
                    if (isDirectory) {
                        if (looksLikeLocale) {
                            // Keep the locale directory visible even when a document provider
                            // reports an unknown archive size; file presence is the key check.
                            // Android document providers can return a null or generic MIME type
                            // for MPQ files. Detect the locale from the standard folder name;
                            // verify locale.MPQ separately as a presence check, never as access permission.
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
                            detectedFiles.add("Data/$relative")
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
            "mpqPaths" to mpqs,
            "detectedFiles" to detectedFiles.distinct().sorted()
        )
    }

    private fun writeRealm(tree: Uri, content: String, requestedLocale: String?): Boolean {
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val data = children(rootUri).firstOrNull {
            it.name.equals("Data", true) &&
                (it.mime == DocumentsContract.Document.MIME_TYPE_DIR || it.mime.isBlank() ||
                 it.mime == "application/octet-stream")
        } ?: return false
        val localeFolders = children(data.uri).filter {
            (it.mime == DocumentsContract.Document.MIME_TYPE_DIR || it.mime.isBlank()) &&
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
