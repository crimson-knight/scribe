package com.crimsonknight.scribe

object ScribeLib {
    init {
        System.loadLibrary("scribe")
    }

    external fun init(): Int
    external fun startRecording(path: String): Int
    external fun stopRecording(): Int
    external fun isRecording(): Int
    external fun startPlayback(path: String): Int
    external fun stopPlayback(): Int
}
