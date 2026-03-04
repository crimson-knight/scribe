package com.crimsonknight.scribe

import android.content.Context
import android.util.Log
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AudioFile
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private const val TAG = "ScribeRecordings"

@Composable
fun RecordingsScreen(
    context: Context,
    modifier: Modifier = Modifier,
) {
    val recordings = remember { mutableStateListOf<File>() }
    var currentlyPlaying by remember { mutableStateOf<String?>(null) }
    var fileToDelete by remember { mutableStateOf<File?>(null) }

    // Scan recordings directory on composition
    LaunchedEffect(Unit) {
        val recordingsDir = File(context.getExternalFilesDir(null), "recordings")
        recordings.clear()
        if (recordingsDir.exists()) {
            val files = recordingsDir.listFiles { file ->
                file.extension.equals("wav", ignoreCase = true)
            }
            if (files != null) {
                recordings.addAll(files.sortedByDescending { it.lastModified() })
            }
        }
    }

    // Delete confirmation dialog
    fileToDelete?.let { file ->
        AlertDialog(
            onDismissRequest = { fileToDelete = null },
            title = { Text("Delete Recording") },
            text = { Text("Delete \"${file.name}\"? This cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (currentlyPlaying == file.absolutePath) {
                            ScribeLib.stopPlayback()
                            currentlyPlaying = null
                        }
                        if (file.delete()) {
                            recordings.remove(file)
                            Log.d(TAG, "Deleted: ${file.name}")
                        } else {
                            Log.e(TAG, "Failed to delete: ${file.name}")
                        }
                        fileToDelete = null
                    }
                ) {
                    Text("Delete", color = Color.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { fileToDelete = null }) {
                    Text("Cancel")
                }
            },
        )
    }

    if (recordings.isEmpty()) {
        // Empty state
        Column(
            modifier = modifier.fillMaxSize().testTag("7.4-empty-state"),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.AudioFile,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "No recordings yet",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Record your first voice memo",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else {
        LazyColumn(
            modifier = modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .testTag("7.4-recordings-list"),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(
                items = recordings,
                key = { it.absolutePath },
            ) { file ->
                RecordingRow(
                    file = file,
                    isPlaying = currentlyPlaying == file.absolutePath,
                    onPlayToggle = {
                        if (currentlyPlaying == file.absolutePath) {
                            ScribeLib.stopPlayback()
                            currentlyPlaying = null
                        } else {
                            // Stop any current playback first
                            if (currentlyPlaying != null) {
                                ScribeLib.stopPlayback()
                            }
                            val result = ScribeLib.startPlayback(file.absolutePath)
                            if (result == 0) {
                                currentlyPlaying = file.absolutePath
                                Log.d(TAG, "Playing: ${file.name}")
                            } else {
                                Log.e(TAG, "startPlayback failed: $result")
                            }
                        }
                    },
                    onDelete = { fileToDelete = file },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RecordingRow(
    file: File,
    isPlaying: Boolean,
    onPlayToggle: () -> Unit,
    onDelete: () -> Unit,
) {
    val dateFormat = remember { SimpleDateFormat("MMM dd, yyyy  HH:mm", Locale.getDefault()) }
    val fileSizeText = remember(file.length()) { formatFileSize(file.length()) }
    val dateText = remember(file.lastModified()) { dateFormat.format(Date(file.lastModified())) }

    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { dismissValue ->
            if (dismissValue == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                false // Don't auto-dismiss; wait for dialog confirmation
            } else {
                false
            }
        }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            val color by animateColorAsState(
                targetValue = if (dismissState.targetValue == SwipeToDismissBoxValue.EndToStart) {
                    Color.Red
                } else {
                    Color.Transparent
                },
                label = "swipe-bg",
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(color)
                    .padding(horizontal = 20.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(
                    imageVector = Icons.Filled.Delete,
                    contentDescription = "Delete",
                    tint = Color.White,
                )
            }
        },
        enableDismissFromStartToEnd = false,
    ) {
        Card(
            modifier = Modifier.fillMaxWidth().testTag("7.4-recording-row-${file.nameWithoutExtension}"),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Start,
            ) {
                IconButton(onClick = onPlayToggle, modifier = Modifier.testTag("7.4-play-button")) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Filled.Stop else Icons.Filled.PlayArrow,
                        contentDescription = if (isPlaying) "Stop playback" else "Play recording",
                        tint = if (isPlaying) Color.Red else MaterialTheme.colorScheme.primary,
                    )
                }

                Spacer(modifier = Modifier.width(8.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = file.nameWithoutExtension,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                    )
                    Text(
                        text = "$dateText  |  $fileSizeText",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

private fun formatFileSize(bytes: Long): String {
    return when {
        bytes < 1024 -> "$bytes B"
        bytes < 1024 * 1024 -> "%.1f KB".format(bytes / 1024.0)
        else -> "%.1f MB".format(bytes / (1024.0 * 1024.0))
    }
}
