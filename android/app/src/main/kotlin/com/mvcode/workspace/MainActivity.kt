package com.mvcode.workspace

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity() {
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingDirectoryResult: MethodChannel.Result? = null
    private var pendingFilesResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SAF_CHANNEL,
        ).setMethodCallHandler(::handleSafCall)
    }

    override fun onDestroy() {
        ioExecutor.shutdownNow()
        pendingDirectoryResult?.error("activity_closed", "A tela foi encerrada.", null)
        pendingFilesResult?.error("activity_closed", "A tela foi encerrada.", null)
        pendingDirectoryResult = null
        pendingFilesResult = null
        super.onDestroy()
    }

    private fun handleSafCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> pickDirectory(result)
            "pickFiles" -> pickFiles(result)
            else -> executeIo(result) {
                when (call.method) {
                    "inspect" -> inspect(requireString(call, "uri"))
                    "listChildren" -> listChildren(requireString(call, "uri"))
                    "readText" -> readText(requireString(call, "uri"))
                    "writeText" -> {
                        writeText(requireString(call, "uri"), requireString(call, "content"))
                        null
                    }
                    "createFile" -> createFile(
                        requireString(call, "parentUri"),
                        requireString(call, "name"),
                    )
                    "createDirectory" -> createDirectory(
                        requireString(call, "parentUri"),
                        requireString(call, "name"),
                    )
                    "rename" -> rename(
                        requireString(call, "uri"),
                        requireString(call, "name"),
                    )
                    "delete" -> {
                        delete(requireString(call, "uri"))
                        null
                    }
                    "copyEntry" -> copyEntry(
                        requireString(call, "uri"),
                        requireString(call, "targetParentUri"),
                    )
                    "moveEntry" -> moveEntry(
                        requireString(call, "uri"),
                        requireString(call, "sourceParentUri"),
                        requireString(call, "targetParentUri"),
                    )
                    "searchText" -> searchText(
                        requireString(call, "rootUri"),
                        requireString(call, "query"),
                        call.argument<Boolean>("caseSensitive") ?: false,
                    )
                    else -> NotImplemented
                }
            }
        }
    }

    private fun executeIo(result: MethodChannel.Result, block: () -> Any?) {
        ioExecutor.execute {
            try {
                val value = block()
                runOnUiThread {
                    if (value === NotImplemented) result.notImplemented() else result.success(value)
                }
            } catch (error: SecurityException) {
                deliverError(result, "permission_denied", "O acesso à pasta foi revogado.")
            } catch (error: IllegalArgumentException) {
                deliverError(result, "invalid_argument", error.message ?: "Parâmetro inválido.")
            } catch (error: InterruptedException) {
                Thread.currentThread().interrupt()
                deliverError(result, "cancelled", "A operação foi cancelada.")
            } catch (error: Exception) {
                deliverError(
                    result,
                    "storage_error",
                    error.message ?: "Falha ao acessar o armazenamento.",
                )
            }
        }
    }

    private fun deliverError(result: MethodChannel.Result, code: String, message: String) {
        runOnUiThread { result.error(code, message, null) }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null || pendingFilesResult != null) {
            result.error("picker_busy", "O seletor de arquivos já está aberto.", null)
            return
        }
        pendingDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, PICK_DIRECTORY_REQUEST)
    }

    private fun pickFiles(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null || pendingFilesResult != null) {
            result.error("picker_busy", "O seletor de arquivos já está aberto.", null)
            return
        }
        pendingFilesResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, PICK_FILES_REQUEST)
    }

    @Deprecated("Activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            PICK_DIRECTORY_REQUEST -> finishDirectoryPicker(resultCode, data)
            PICK_FILES_REQUEST -> finishFilesPicker(resultCode, data)
        }
    }

    private fun finishDirectoryPicker(resultCode: Int, data: Intent?) {
        val result = pendingDirectoryResult ?: return
        pendingDirectoryResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val requiredFlags =
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            val flags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            if ((flags and requiredFlags) != requiredFlags) {
                throw SecurityException("A pasta precisa permitir leitura e escrita.")
            }
            contentResolver.takePersistableUriPermission(uri, flags)
            executeIo(result) { inspect(uri.toString(), preserveInputUri = true) }
        } catch (_: SecurityException) {
            result.error("permission_denied", "A pasta não concedeu acesso de leitura e escrita.", null)
        }
    }

    private fun finishFilesPicker(resultCode: Int, data: Intent?) {
        val result = pendingFilesResult ?: return
        pendingFilesResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        val uris = LinkedHashSet<Uri>()
        data.data?.let(uris::add)
        data.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) uris += clip.getItemAt(index).uri
        }
        for (uri in uris) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // Some providers only grant access for the current task; it is enough to import.
            }
        }
        executeIo(result) { uris.map { inspect(it.toString()) } }
    }

    private fun inspect(rawUri: String, preserveInputUri: Boolean = false): Map<String, Any> {
        val inputUri = Uri.parse(rawUri)
        val queryUri = documentUri(inputUri)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_FLAGS,
        )
        runCatching {
            contentResolver.query(queryUri, projection, null, null, null)?.use { cursor ->
                check(cursor.moveToFirst()) { "O item não existe mais." }
                val mime = cursor.string(DocumentsContract.Document.COLUMN_MIME_TYPE)
                return mapOf(
                    "uri" to if (preserveInputUri) rawUri else queryUri.toString(),
                    "name" to cursor.string(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                    "mimeType" to mime,
                    "isDirectory" to (mime == DocumentsContract.Document.MIME_TYPE_DIR),
                    "size" to cursor.long(DocumentsContract.Document.COLUMN_SIZE),
                    "lastModified" to cursor.long(DocumentsContract.Document.COLUMN_LAST_MODIFIED),
                    "flags" to cursor.long(DocumentsContract.Document.COLUMN_FLAGS),
                )
            }
        }

        contentResolver.query(
            inputUri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            check(cursor.moveToFirst()) { "O arquivo selecionado não está disponível." }
            val name = cursor.string(OpenableColumns.DISPLAY_NAME)
            return mapOf(
                "uri" to rawUri,
                "name" to name,
                "mimeType" to (contentResolver.getType(inputUri) ?: mimeFor(name)),
                "isDirectory" to false,
                "size" to cursor.long(OpenableColumns.SIZE),
                "lastModified" to 0L,
                "flags" to 0L,
            )
        }
        error("O provedor de documentos não respondeu.")
    }

    private fun listChildren(rawUri: String): List<Map<String, Any>> {
        val treeOrDocumentUri = Uri.parse(rawUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeOrDocumentUri,
            documentId(treeOrDocumentUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_FLAGS,
        )
        val entries = ArrayList<Map<String, Any>>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                require(entries.size < MAX_DIRECTORY_ITEMS) {
                    "A pasta excede o limite de $MAX_DIRECTORY_ITEMS itens."
                }
                val childId = cursor.string(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val mime = cursor.string(DocumentsContract.Document.COLUMN_MIME_TYPE)
                entries += mapOf(
                    "uri" to DocumentsContract.buildDocumentUriUsingTree(treeOrDocumentUri, childId).toString(),
                    "name" to cursor.string(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                    "mimeType" to mime,
                    "isDirectory" to (mime == DocumentsContract.Document.MIME_TYPE_DIR),
                    "size" to cursor.long(DocumentsContract.Document.COLUMN_SIZE),
                    "lastModified" to cursor.long(DocumentsContract.Document.COLUMN_LAST_MODIFIED),
                    "flags" to cursor.long(DocumentsContract.Document.COLUMN_FLAGS),
                )
            }
        } ?: error("O provedor de documentos não respondeu.")
        return entries
    }

    private fun readText(rawUri: String): String {
        contentResolver.openInputStream(Uri.parse(rawUri))?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            var total = 0
            while (true) {
                checkNotInterrupted()
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                require(total <= MAX_TEXT_BYTES) { "O arquivo excede o limite de 12 MB." }
                output.write(buffer, 0, count)
            }
            val bytes = output.toByteArray()
            require(bytes.none { it == 0.toByte() }) {
                "O arquivo parece ser binário e não pode ser editado como texto."
            }
            return String(bytes, StandardCharsets.UTF_8)
        }
        error("Não foi possível abrir o arquivo.")
    }

    private fun writeText(rawUri: String, content: String) {
        val uri = Uri.parse(rawUri)
        val bytes = content.toByteArray(StandardCharsets.UTF_8)
        require(bytes.size <= MAX_TEXT_BYTES) { "O arquivo excede o limite de 12 MB." }

        val recovery = File(cacheDir, "mv-recovery-${rawUri.hashCode()}.tmp")
        val previous = runCatching { readText(rawUri).toByteArray(StandardCharsets.UTF_8) }.getOrNull()
        if (previous != null) FileOutputStream(recovery).use { it.write(previous) }

        try {
            writeBytes(uri, bytes)
            if (recovery.exists()) recovery.delete()
        } catch (error: Exception) {
            if (previous != null) runCatching { writeBytes(uri, previous) }
            throw error
        }
    }

    private fun writeBytes(uri: Uri, bytes: ByteArray) {
        contentResolver.openFileDescriptor(uri, "rwt")?.use { descriptor ->
            FileOutputStream(descriptor.fileDescriptor).use { output ->
                output.write(bytes)
                output.flush()
                descriptor.fileDescriptor.sync()
            }
        } ?: error("Não foi possível abrir o arquivo para escrita.")
    }

    private fun createFile(rawParentUri: String, name: String): Map<String, Any> {
        validateName(name)
        return inspect(createDocument(rawParentUri, mimeFor(name), name).toString())
    }

    private fun createDirectory(rawParentUri: String, name: String): Map<String, Any> {
        validateName(name)
        return inspect(
            createDocument(rawParentUri, DocumentsContract.Document.MIME_TYPE_DIR, name).toString(),
        )
    }

    private fun createDocument(rawParentUri: String, mime: String, name: String): Uri {
        val parentDocumentUri = documentUri(Uri.parse(rawParentUri))
        return DocumentsContract.createDocument(contentResolver, parentDocumentUri, mime, name)
            ?: error("O provedor não criou o item.")
    }

    private fun rename(rawUri: String, name: String): Map<String, Any> {
        validateName(name)
        val renamed = DocumentsContract.renameDocument(contentResolver, Uri.parse(rawUri), name)
            ?: error("O provedor não permite renomear este item.")
        return inspect(renamed.toString())
    }

    private fun delete(rawUri: String) {
        check(DocumentsContract.deleteDocument(contentResolver, Uri.parse(rawUri))) {
            "O provedor não permite excluir este item."
        }
    }

    private fun copyEntry(rawSourceUri: String, rawTargetParentUri: String): Map<String, Any> {
        val source = Uri.parse(rawSourceUri)
        val target = Uri.parse(rawTargetParentUri)
        require(!isSameOrDescendant(source, target)) {
            "Não é possível copiar uma pasta para dentro dela mesma."
        }
        val copied = copyRecursive(source, rawTargetParentUri, CopyBudget())
        return inspect(copied.toString())
    }

    private fun moveEntry(
        rawSourceUri: String,
        rawSourceParentUri: String,
        rawTargetParentUri: String,
    ): Map<String, Any> {
        require(rawSourceParentUri.isNotBlank()) { "A pasta de origem não foi identificada." }
        val source = Uri.parse(rawSourceUri)
        val target = Uri.parse(rawTargetParentUri)
        require(!isSameOrDescendant(source, target)) {
            "Não é possível mover uma pasta para dentro dela mesma."
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val moved = runCatching {
                DocumentsContract.moveDocument(
                    contentResolver,
                    source,
                    documentUri(Uri.parse(rawSourceParentUri)),
                    documentUri(target),
                )
            }.getOrNull()
            if (moved != null) return inspect(moved.toString())
        }

        val copied = copyRecursive(source, rawTargetParentUri, CopyBudget())
        check(DocumentsContract.deleteDocument(contentResolver, source)) {
            "A cópia foi criada, mas a origem não pôde ser removida."
        }
        return inspect(copied.toString())
    }

    private fun copyRecursive(source: Uri, rawTargetParentUri: String, budget: CopyBudget): Uri {
        checkNotInterrupted()
        require(budget.items.incrementAndGet() <= MAX_COPY_ITEMS) {
            "A operação excedeu o limite de $MAX_COPY_ITEMS itens."
        }
        val metadata = inspect(source.toString())
        val name = metadata["name"] as String
        val mime = metadata["mimeType"] as String
        val directory = metadata["isDirectory"] as Boolean
        val created = createDocument(
            rawTargetParentUri,
            if (directory) DocumentsContract.Document.MIME_TYPE_DIR else mime,
            name,
        )
        try {
            if (directory) {
                for (child in listChildren(source.toString())) {
                    copyRecursive(Uri.parse(child["uri"] as String), created.toString(), budget)
                }
                return created
            }

            contentResolver.openInputStream(source)?.use { input ->
                contentResolver.openOutputStream(created, "w")?.use { output ->
                    val bufferedInput = BufferedInputStream(input)
                    val bufferedOutput = BufferedOutputStream(output)
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE * 2)
                    while (true) {
                        checkNotInterrupted()
                        val count = bufferedInput.read(buffer)
                        if (count < 0) break
                        val total = budget.bytes.addAndGet(count.toLong())
                        require(total <= MAX_COPY_BYTES) { "A operação excedeu o limite de 1 GB." }
                        bufferedOutput.write(buffer, 0, count)
                    }
                    bufferedOutput.flush()
                } ?: error("Não foi possível gravar a cópia.")
            } ?: error("Não foi possível ler o arquivo de origem.")
            return created
        } catch (error: Exception) {
            runCatching { DocumentsContract.deleteDocument(contentResolver, created) }
            throw error
        }
    }

    private fun searchText(
        rawRootUri: String,
        query: String,
        caseSensitive: Boolean,
    ): List<Map<String, Any>> {
        require(query.isNotBlank() && query.length <= 200) { "A pesquisa é inválida." }
        val results = ArrayList<Map<String, Any>>()
        val visited = AtomicInteger(0)
        searchDirectory(Uri.parse(rawRootUri), "", query, caseSensitive, results, visited)
        return results
    }

    private fun searchDirectory(
        directory: Uri,
        relativePath: String,
        query: String,
        caseSensitive: Boolean,
        results: MutableList<Map<String, Any>>,
        visited: AtomicInteger,
    ) {
        if (results.size >= MAX_SEARCH_RESULTS || visited.get() >= MAX_SEARCH_FILES) return
        for (item in listChildren(directory.toString())) {
            checkNotInterrupted()
            if (results.size >= MAX_SEARCH_RESULTS || visited.incrementAndGet() > MAX_SEARCH_FILES) return
            val name = item["name"] as String
            val uri = Uri.parse(item["uri"] as String)
            val path = if (relativePath.isEmpty()) name else "$relativePath/$name"
            if (item["isDirectory"] as Boolean) {
                if (name.lowercase(Locale.ROOT) !in SEARCH_IGNORED_FOLDERS) {
                    searchDirectory(uri, path, query, caseSensitive, results, visited)
                }
                continue
            }
            val size = item["size"] as Long
            if (size > MAX_SEARCH_FILE_BYTES || isProbablyBinary(name)) continue
            searchFile(uri, name, path, query, caseSensitive, results)
        }
    }

    private fun searchFile(
        uri: Uri,
        name: String,
        path: String,
        query: String,
        caseSensitive: Boolean,
        results: MutableList<Map<String, Any>>,
    ) {
        val content = runCatching {
            contentResolver.openInputStream(uri)?.bufferedReader(StandardCharsets.UTF_8)?.use {
                val buffer = CharArray(MAX_SEARCH_FILE_BYTES.toInt() + 1)
                val count = it.read(buffer)
                if (count <= 0 || count > MAX_SEARCH_FILE_BYTES) "" else String(buffer, 0, count)
            } ?: ""
        }.getOrDefault("")
        if (content.indexOf('\u0000') >= 0) return
        val needle = if (caseSensitive) query else query.lowercase(Locale.ROOT)
        content.lineSequence().forEachIndexed { lineIndex, line ->
            if (results.size >= MAX_SEARCH_RESULTS) return
            val haystack = if (caseSensitive) line else line.lowercase(Locale.ROOT)
            var from = 0
            while (results.size < MAX_SEARCH_RESULTS) {
                val column = haystack.indexOf(needle, from)
                if (column < 0) break
                results += mapOf(
                    "uri" to uri.toString(),
                    "name" to name,
                    "path" to path,
                    "line" to lineIndex + 1,
                    "column" to column + 1,
                    "preview" to line.take(240),
                )
                from = column + needle.length.coerceAtLeast(1)
            }
        }
    }

    private fun isSameOrDescendant(source: Uri, target: Uri): Boolean {
        if (source == target) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return runCatching {
                DocumentsContract.isChildDocument(
                    contentResolver,
                    documentUri(source),
                    documentUri(target),
                )
            }.getOrDefault(false)
        }
        return false
    }

    private fun isProbablyBinary(name: String): Boolean {
        return name.substringAfterLast('.', "").lowercase(Locale.ROOT) in BINARY_EXTENSIONS
    }

    private fun validateName(name: String) {
        require(
            name.isNotBlank() &&
                name != "." &&
                name != ".." &&
                !name.contains('/') &&
                !name.contains('\\') &&
                !name.contains('\u0000') &&
                name.length <= 180,
        ) { "Nome de arquivo ou pasta inválido." }
    }

    private fun mimeFor(name: String): String = when (
        name.substringAfterLast('.', "").lowercase(Locale.ROOT)
    ) {
        "html", "htm" -> "text/html"
        "css" -> "text/css"
        "js", "mjs", "cjs" -> "text/javascript"
        "json" -> "application/json"
        "svg" -> "image/svg+xml"
        "xml" -> "application/xml"
        "md", "txt", "yaml", "yml", "ts", "tsx", "jsx", "dart", "kt", "java", "py" ->
            "text/plain"
        else -> "text/plain"
    }

    private fun documentUri(uri: Uri): Uri {
        return if (DocumentsContract.isTreeUri(uri)) {
            DocumentsContract.buildDocumentUriUsingTree(uri, documentId(uri))
        } else {
            uri
        }
    }

    private fun documentId(uri: Uri): String {
        return runCatching { DocumentsContract.getDocumentId(uri) }
            .getOrElse { DocumentsContract.getTreeDocumentId(uri) }
    }

    private fun requireString(call: MethodCall, key: String): String {
        return call.argument<String>(key)?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Parâmetro ausente: $key")
    }

    private fun checkNotInterrupted() {
        if (Thread.currentThread().isInterrupted) throw InterruptedException()
    }

    private fun Cursor.string(column: String): String {
        val index = getColumnIndex(column)
        return if (index >= 0 && !isNull(index)) getString(index) else ""
    }

    private fun Cursor.long(column: String): Long {
        val index = getColumnIndex(column)
        return if (index >= 0 && !isNull(index)) getLong(index) else 0L
    }

    private class CopyBudget {
        val items = AtomicInteger(0)
        val bytes = AtomicLong(0)
    }

    private object NotImplemented

    companion object {
        private const val SAF_CHANNEL = "com.mvcode.workspace/saf"
        private const val PICK_DIRECTORY_REQUEST = 4101
        private const val PICK_FILES_REQUEST = 4102
        private const val MAX_DIRECTORY_ITEMS = 5_000
        private const val MAX_TEXT_BYTES = 12 * 1024 * 1024
        private const val MAX_SEARCH_RESULTS = 500
        private const val MAX_SEARCH_FILES = 8_000
        private const val MAX_SEARCH_FILE_BYTES = 1_048_576L
        private const val MAX_COPY_ITEMS = 10_000
        private const val MAX_COPY_BYTES = 1024L * 1024 * 1024

        private val SEARCH_IGNORED_FOLDERS = setOf(
            ".git",
            ".gradle",
            ".dart_tool",
            "node_modules",
            "build",
        )
        private val BINARY_EXTENSIONS = setOf(
            "apk", "aab", "zip", "jar", "class", "dex", "so", "exe", "dll",
            "png", "jpg", "jpeg", "gif", "webp", "ico", "pdf", "epub", "mp3",
            "mp4", "wav", "ttf", "otf", "woff", "woff2", "db", "sqlite",
        )
    }
}
