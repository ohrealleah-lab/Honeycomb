package com.leah.honeycomb.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import com.leah.honeycomb.R
import kotlinx.coroutines.flow.StateFlow

class SoundManager(private val context: Context, private val isSoundEnabled: StateFlow<Boolean>) {

    private var soundPool: SoundPool? = null
    private var shuffleSoundId: Int = 0
    private var victorySoundId: Int = 0
    private var snapSoundId: Int = 0

    init {
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        soundPool = SoundPool.Builder()
            .setMaxStreams(5)
            .setAudioAttributes(audioAttributes)
            .build()

        soundPool?.let {
            shuffleSoundId = it.load(context, R.raw.shuffle, 1)
            victorySoundId = it.load(context, R.raw.victory, 1)
            snapSoundId = it.load(context, R.raw.snap, 1)
        }
    }

    fun playEffect(name: String) {
        if (!isSoundEnabled.value) return

        val soundId = when (name.lowercase()) {
            "shuffle" -> shuffleSoundId
            "victory" -> victorySoundId
            "snap" -> snapSoundId
            else -> return
        }
        
        if (soundId != 0) {
            soundPool?.play(soundId, 1.0f, 1.0f, 0, 0, 1.0f)
        }
    }

    fun playSystemSound(name: String, volume: Float) {
        if (!isSoundEnabled.value) return
        
        val soundId = when (name) {
            "Tink", "Pop" -> snapSoundId
            else -> return
        }

        if (soundId != 0) {
            soundPool?.play(soundId, volume, volume, 0, 0, 1.0f)
        }
    }

    fun release() {
        soundPool?.release()
        soundPool = null
    }
}
