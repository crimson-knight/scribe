package com.crimsonknight.scribe

import android.Manifest
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.graphics.vector.ImageVector

private const val TAG = "ScribeMain"

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val initResult = ScribeLib.init()
        if (initResult != 0) {
            Log.e(TAG, "Crystal runtime initialization failed: $initResult")
        } else {
            Log.d(TAG, "Crystal runtime initialized successfully")
        }

        setContent {
            MaterialTheme {
                ScribeApp()
            }
        }
    }
}

private data class NavTab(
    val label: String,
    val icon: ImageVector,
)

@Composable
private fun ScribeApp() {
    val tabs = remember {
        listOf(
            NavTab("Record", Icons.Filled.Mic),
            NavTab("Recordings", Icons.AutoMirrored.Filled.List),
            NavTab("Settings", Icons.Filled.Settings),
        )
    }

    var selectedTab by remember { mutableIntStateOf(0) }
    var hasAudioPermission by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasAudioPermission = granted
        if (!granted) {
            Log.w(TAG, "RECORD_AUDIO permission denied")
        }
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        modifier = Modifier.testTag(when(index) {
                            0 -> "nav-tab-record"
                            1 -> "nav-tab-recordings"
                            else -> "nav-tab-settings"
                        }),
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) },
                    )
                }
            }
        }
    ) { innerPadding ->
        val modifier = Modifier.padding(innerPadding)

        when (selectedTab) {
            0 -> RecordScreen(
                context = androidx.compose.ui.platform.LocalContext.current,
                hasAudioPermission = hasAudioPermission,
                onRequestPermission = {
                    permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                },
                modifier = modifier,
            )
            1 -> RecordingsScreen(
                context = androidx.compose.ui.platform.LocalContext.current,
                modifier = modifier,
            )
            2 -> SettingsScreen(
                context = androidx.compose.ui.platform.LocalContext.current,
                modifier = modifier,
            )
        }
    }
}
