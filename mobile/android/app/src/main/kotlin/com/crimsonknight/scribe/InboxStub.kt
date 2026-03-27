package com.crimsonknight.scribe

// =============================================================================
// Epic 14 Story 14.5: Android Inbox — Architecture Stub
// =============================================================================
//
// This is a placeholder for future Android inbox implementation.
// The iOS inbox (Stories 14.1-14.4) uses iCloud Drive for thread file sync,
// which is not available on Android.
//
// ARCHITECTURE OPTIONS FOR ANDROID SYNC:
//
// Option A: Google Drive API
//   - Pros: Native Android ecosystem, user already has Google account
//   - Cons: Requires OAuth 2.0 setup, Drive API v3 SDK, more complex auth flow
//   - Implementation: Use Google Drive REST API to read/write .md files
//   - File format: Same thread .md with YAML frontmatter (portable)
//
// Option B: Shared Backend / API
//   - Pros: Platform-agnostic, works for both iOS and Android
//   - Cons: Requires server infrastructure, ongoing maintenance
//   - Implementation: REST API backed by file storage or database
//
// Option C: Local-Only with Manual Export
//   - Pros: Simplest, no sync dependencies
//   - Cons: No cross-device sync, manual file transfer needed
//   - Implementation: Read/write .md files in app's external files directory
//
// RECOMMENDED: Option A (Google Drive) for parity with iOS iCloud approach.
//
// SPEECH RECOGNITION:
//   - Android SpeechRecognizer API (similar to iOS SFSpeechRecognizer)
//   - On-device models available via ML Kit or Google Speech Services
//   - Intent-based: android.speech.RecognizerIntent
//   - Permission: android.permission.RECORD_AUDIO (already granted from Epic 7)
//
// FILE WATCHING:
//   - FileObserver API for local file changes
//   - For Google Drive: Drive API change notifications or periodic polling
//
// THREAD FILE FORMAT:
//   Same .md with YAML frontmatter as iOS/macOS:
//   ---
//   id: <uuid>
//   title: "Thread title"
//   agent: default
//   status: active
//   created: 2026-03-04T10:30:00Z
//   updated: 2026-03-04T10:30:00Z
//   ---
//   ## User — 10:30 AM
//   Message content here.
//
// =============================================================================

// TODO: Implement InboxScreen composable (similar to RecordingsScreen)
// TODO: Implement ThreadDetailScreen composable
// TODO: Implement Google Drive sync service (or chosen sync approach)
// TODO: Implement Android SpeechRecognizer wrapper for dictation
// TODO: Add YAML frontmatter parser for Kotlin (simple string splitting)
// TODO: Add inbox tab to MainActivity bottom navigation
