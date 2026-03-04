package com.crimsonknight.scribe

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

private const val PREFS_NAME = "scribe_settings"
private const val KEY_SAVE_LOCATION = "save_location"
private const val KEY_AUDIO_FORMAT = "audio_format"

private const val SAVE_LOCAL = "local"
private const val SAVE_GOOGLE_DRIVE = "google_drive"
private const val FORMAT_WAV = "wav"
private const val FORMAT_M4A = "m4a"

@Composable
fun SettingsScreen(
    context: Context,
    modifier: Modifier = Modifier,
) {
    val prefs = remember {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    var saveLocation by remember {
        mutableStateOf(prefs.getString(KEY_SAVE_LOCATION, SAVE_LOCAL) ?: SAVE_LOCAL)
    }
    var audioFormat by remember {
        mutableStateOf(prefs.getString(KEY_AUDIO_FORMAT, FORMAT_WAV) ?: FORMAT_WAV)
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        // Section 1: Save Location
        Text(
            text = "Save Location",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary,
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
            ) {
                SettingsRadioOption(
                    label = "Local Only",
                    selected = saveLocation == SAVE_LOCAL,
                    enabled = true,
                    onClick = {
                        saveLocation = SAVE_LOCAL
                        prefs.edit().putString(KEY_SAVE_LOCATION, SAVE_LOCAL).apply()
                    },
                    modifier = Modifier.testTag("7.6-option-local"),
                )

                Spacer(modifier = Modifier.height(8.dp))

                SettingsRadioOption(
                    label = "Google Drive (Coming Soon)",
                    selected = saveLocation == SAVE_GOOGLE_DRIVE,
                    enabled = false,
                    onClick = { /* disabled */ },
                    modifier = Modifier.testTag("7.6-option-google-drive"),
                )
            }
        }

        // Section 2: Audio Format
        Text(
            text = "Audio Format",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary,
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
            ) {
                SettingsRadioOption(
                    label = "WAV \u2014 Lossless (~10 MB/min)",
                    selected = audioFormat == FORMAT_WAV,
                    enabled = true,
                    onClick = {
                        audioFormat = FORMAT_WAV
                        prefs.edit().putString(KEY_AUDIO_FORMAT, FORMAT_WAV).apply()
                    },
                    modifier = Modifier.testTag("7.7-option-wav"),
                )

                Spacer(modifier = Modifier.height(8.dp))

                SettingsRadioOption(
                    label = "M4A \u2014 Compressed (~1 MB/min)",
                    selected = audioFormat == FORMAT_M4A,
                    enabled = true,
                    onClick = {
                        audioFormat = FORMAT_M4A
                        prefs.edit().putString(KEY_AUDIO_FORMAT, FORMAT_M4A).apply()
                    },
                    modifier = Modifier.testTag("7.7-option-m4a"),
                )
            }
        }
    }
}

@Composable
private fun SettingsRadioOption(
    label: String,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(
            selected = selected,
            onClick = onClick,
            enabled = enabled,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = if (enabled) {
                MaterialTheme.colorScheme.onSurface
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
            },
        )
    }
}
