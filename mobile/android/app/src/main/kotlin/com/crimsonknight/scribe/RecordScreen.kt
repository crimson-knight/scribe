package com.crimsonknight.scribe

import android.content.Context
import android.util.Log
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private const val TAG = "ScribeRecord"

@Composable
fun RecordScreen(
    context: Context,
    hasAudioPermission: Boolean,
    onRequestPermission: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var isRecording by remember { mutableStateOf(false) }
    var elapsedSeconds by remember { mutableIntStateOf(0) }
    var statusText by remember { mutableStateOf("Ready to record") }
    var currentRecordingPath by remember { mutableStateOf<String?>(null) }

    // Timer: increments every second while recording
    LaunchedEffect(isRecording) {
        if (isRecording) {
            while (true) {
                delay(1000L)
                elapsedSeconds++
            }
        }
    }

    val timerDisplay = remember(elapsedSeconds) {
        val minutes = elapsedSeconds / 60
        val seconds = elapsedSeconds % 60
        "%02d:%02d".format(minutes, seconds)
    }

    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // Timer display
        Text(
            text = timerDisplay,
            style = MaterialTheme.typography.displayLarge,
            color = if (isRecording) Color.Red else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.testTag("7.2-timer-display"),
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Record / Stop button
        Button(
            onClick = {
                if (isRecording) {
                    // Stop recording
                    val result = ScribeLib.stopRecording()
                    if (result == 0) {
                        val filename = currentRecordingPath
                            ?.let { File(it).name }
                            ?: "recording"
                        statusText = "Saved: $filename"
                        Log.d(TAG, "Recording stopped: $currentRecordingPath")
                    } else {
                        statusText = "Error stopping recording"
                        Log.e(TAG, "stopRecording failed: $result")
                    }
                    isRecording = false
                    elapsedSeconds = 0
                    currentRecordingPath = null
                } else {
                    // Check permission first
                    if (!hasAudioPermission) {
                        onRequestPermission()
                        return@Button
                    }

                    // Prepare output path
                    val recordingsDir = File(
                        context.getExternalFilesDir(null),
                        "recordings"
                    )
                    if (!recordingsDir.exists()) {
                        recordingsDir.mkdirs()
                    }

                    val timestamp = SimpleDateFormat(
                        "yyyyMMdd_HHmmss",
                        Locale.US
                    ).format(Date())
                    val outputFile = recordingsDir.resolve("recording_${timestamp}.wav")
                    val path = outputFile.absolutePath

                    // Start recording
                    val result = ScribeLib.startRecording(path)
                    if (result == 0) {
                        isRecording = true
                        elapsedSeconds = 0
                        currentRecordingPath = path
                        statusText = "Recording..."
                        Log.d(TAG, "Recording started: $path")
                    } else {
                        statusText = "Error starting recording"
                        Log.e(TAG, "startRecording failed: $result")
                    }
                }
            },
            modifier = Modifier.size(80.dp).testTag("7.2-record-button"),
            shape = CircleShape,
            colors = ButtonDefaults.buttonColors(
                containerColor = if (isRecording) Color.Red else MaterialTheme.colorScheme.primary,
            ),
        ) {
            Icon(
                imageVector = if (isRecording) Icons.Filled.Stop else Icons.Filled.Mic,
                contentDescription = if (isRecording) "Stop recording" else "Start recording",
                modifier = Modifier.size(36.dp),
                tint = Color.White,
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Status text
        Text(
            text = statusText,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.testTag("7.2-status-text"),
        )
    }
}
