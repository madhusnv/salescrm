package com.koncrm.counselor.recordings

import android.content.Context
import android.net.Uri
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.folderStore by preferencesDataStore(name = "recording_folder_store")

/**
 * Manages the user-selected recording folder (external call recording app folder).
 * Uses Android's Storage Access Framework (SAF) to persist folder access.
 */
class RecordingFolderStore(private val context: Context) {
    private val folderUriKey = stringPreferencesKey("recording_folder_uri")
    private val folderNameKey = stringPreferencesKey("recording_folder_name")

    /**
     * Flow of the currently selected folder URI (null if not set)
     */
    fun folderUriFlow(): Flow<String?> {
        return context.folderStore.data.map { prefs ->
            prefs[folderUriKey]
        }
    }

    /**
     * Flow of the folder display name
     */
    fun folderNameFlow(): Flow<String?> {
        return context.folderStore.data.map { prefs ->
            prefs[folderNameKey]
        }
    }

    /**
     * Get the current folder URI (blocking)
     */
    suspend fun getFolderUri(): Uri? {
        val uriString = context.folderStore.data.first()[folderUriKey]
        return uriString?.let { Uri.parse(it) }
    }

    /**
     * Save the selected folder URI and persist permissions
     */
    suspend fun setFolder(uri: Uri, displayName: String) {
        // Take persistent read permissions
        val flags = android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
        context.contentResolver.takePersistableUriPermission(uri, flags)

        context.folderStore.edit { prefs ->
            prefs[folderUriKey] = uri.toString()
            prefs[folderNameKey] = displayName
        }
    }

    /**
     * Clear the selected folder
     */
    suspend fun clearFolder() {
        context.folderStore.edit { prefs ->
            prefs.remove(folderUriKey)
            prefs.remove(folderNameKey)
        }
    }

    /**
     * List audio files in the selected folder
     */
    fun listRecordingFiles(): List<RecordingFile> {
        val uriString = kotlinx.coroutines.runBlocking {
            context.folderStore.data.first()[folderUriKey]
        } ?: return emptyList()

        val folderUri = Uri.parse(uriString)
        val folder = DocumentFile.fromTreeUri(context, folderUri) ?: return emptyList()

        return folder.listFiles()
            .filter { file ->
                file.isFile && file.type?.startsWith("audio/") == true
            }
            .mapNotNull { file ->
                val name = file.name ?: return@mapNotNull null
                RecordingFile(
                    uri = file.uri,
                    name = name,
                    lastModified = file.lastModified(),
                    size = file.length()
                )
            }
            .sortedByDescending { it.lastModified }
    }

    /**
     * Find recordings matching a phone number in filename (by last 10 digits)
     */
    fun findRecordingsForPhone(phoneNumber: String): List<RecordingFile> {
        val normalizedPhone = normalizePhone(phoneNumber)
        if (normalizedPhone.length < 7) return emptyList()

        return listRecordingFiles().filter { file ->
            val digits = file.name.filter { it.isDigit() }
            digits.contains(normalizedPhone) ||
                    normalizedPhone.takeLast(7).let { digits.contains(it) }
        }
    }

    private fun normalizePhone(phone: String): String {
        val digits = phone.filter { it.isDigit() }
        return if (digits.length > 10) digits.takeLast(10) else digits
    }
}

data class RecordingFile(
    val uri: Uri,
    val name: String,
    val lastModified: Long,
    val size: Long
)
