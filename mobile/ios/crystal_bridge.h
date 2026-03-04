#pragma once
/*
 * crystal_bridge.h
 *
 * C interface to the Scribe Crystal audio library compiled as a static library
 * (libscribe.a) for iOS.  Include this file as the Xcode
 * "Objective-C Bridging Header" so Swift can call these functions directly.
 *
 * Build the static library with:
 *   ./build_crystal_lib.sh
 * then add libscribe.a to Xcode → Build Phases →
 * "Link Binary with Libraries".
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize the Crystal runtime (GC, fibers, threads).
 * MUST be called once from the main thread before any other scribe_* call.
 * Safe to call multiple times.
 *
 * @return  0 on success, -1 on error.
 */
int scribe_init(void);

/**
 * Start microphone recording to a WAV file at the given path.
 *
 * AVAudioSession must be configured for recording (.record category, active)
 * before calling this function.
 *
 * @param output_path  Absolute filesystem path for the output WAV file.
 *                     The directory must already exist and be writable.
 * @return  0 on success.
 *         -1 if a recording is already in progress or on any error.
 */
int scribe_start_recording(const char *output_path);

/**
 * Stop the current recording and finalize the output WAV file.
 *
 * @return  0 on success.
 *         -1 if no recording is active or on any error.
 */
int scribe_stop_recording(void);

/**
 * Query whether a recording is currently in progress.
 *
 * @return  1 if recording is active, 0 otherwise.
 */
int scribe_is_recording(void);

/**
 * Start playback of a recording file at the given path.
 * If playback is already in progress it will be stopped before starting the new file.
 *
 * @param file_path  Absolute filesystem path to the WAV file to play.
 * @return  0 on success, -1 on error.
 */
int scribe_start_playback(const char *file_path);

/**
 * Stop any currently active playback.
 *
 * @return  0 on success, -1 on error.
 */
int scribe_stop_playback(void);

#ifdef __cplusplus
}
#endif
