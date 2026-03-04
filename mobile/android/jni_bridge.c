/*
 * jni_bridge.c — JNI glue between Kotlin and Crystal shared library
 *
 * This file provides the native method implementations for ScribeLib.kt.
 * It stores the JavaVM pointer, initializes the Crystal runtime, and
 * forwards calls to the Crystal C API exported by scribe_bridge.cr.
 *
 * Build: compiled into libscribe.so alongside the Crystal object files
 */

#include <jni.h>
#include <android/log.h>
#include <string.h>
#include <stdlib.h>

#define LOG_TAG "Scribe"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* -- Crystal C API (exported by scribe_bridge.cr) ------------------------- */

extern int scribe_init(void);
extern int scribe_start_recording(const char *path);
extern int scribe_stop_recording(void);
extern int scribe_is_recording(void);
extern int scribe_start_playback(const char *path);
extern int scribe_stop_playback(void);

/* -- Trace helper (called by Crystal via LibTrace) ------------------------ */

void crystal_trace(const char *msg) {
    LOGE("CRYSTAL_TRACE: %s", msg);
}

/* -- Global state --------------------------------------------------------- */

static JavaVM *g_jvm = NULL;

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    (void)reserved;
    g_jvm = vm;
    LOGI("JNI_OnLoad: JavaVM stored");
    return JNI_VERSION_1_6;
}

/* -- JNI native method implementations ------------------------------------ */

JNIEXPORT jint JNICALL
Java_com_crimsonknight_scribe_ScribeLib_init(JNIEnv *env, jobject thiz) {
    (void)env; (void)thiz;
    LOGI("ScribeLib.init() called");
    int result = scribe_init();
    LOGI("scribe_init returned %d", result);
    return result;
}

JNIEXPORT jint JNICALL
Java_com_crimsonknight_scribe_ScribeLib_startRecording(
    JNIEnv *env, jobject thiz, jstring path) {
    (void)thiz;
    const char *c_path = (*env)->GetStringUTFChars(env, path, NULL);
    if (!c_path) {
        LOGE("startRecording: GetStringUTFChars failed");
        return -1;
    }
    LOGI("startRecording: path=%s", c_path);
    int result = scribe_start_recording(c_path);
    (*env)->ReleaseStringUTFChars(env, path, c_path);
    LOGI("startRecording: result=%d", result);
    return result;
}

JNIEXPORT jint JNICALL
Java_com_crimsonknight_scribe_ScribeLib_stopRecording(
    JNIEnv *env, jobject thiz) {
    (void)env; (void)thiz;
    LOGI("stopRecording called");
    int result = scribe_stop_recording();
    LOGI("stopRecording: result=%d", result);
    return result;
}

JNIEXPORT jint JNICALL
Java_com_crimsonknight_scribe_ScribeLib_isRecording(
    JNIEnv *env, jobject thiz) {
    (void)env; (void)thiz;
    return scribe_is_recording();
}

JNIEXPORT jint JNICALL
Java_com_crimsonknight_scribe_ScribeLib_startPlayback(
    JNIEnv *env, jobject thiz, jstring path) {
    (void)thiz;
    const char *c_path = (*env)->GetStringUTFChars(env, path, NULL);
    if (!c_path) {
        LOGE("startPlayback: GetStringUTFChars failed");
        return -1;
    }
    LOGI("startPlayback: path=%s", c_path);
    int result = scribe_start_playback(c_path);
    (*env)->ReleaseStringUTFChars(env, path, c_path);
    LOGI("startPlayback: result=%d", result);
    return result;
}

JNIEXPORT jint JNICALL
Java_com_crimsonknight_scribe_ScribeLib_stopPlayback(
    JNIEnv *env, jobject thiz) {
    (void)env; (void)thiz;
    LOGI("stopPlayback called");
    return scribe_stop_playback();
}
