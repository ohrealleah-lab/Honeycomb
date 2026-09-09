package com.leah.honeycomb.audio

object UISound {
    @Volatile
    var backend: SoundManager? = null
    
    fun play(name: String) {
        backend?.playEffect(name)
    }
    
    fun click() {
        backend?.playSystemSound("Tink", 1.0f)
    }
    
    fun tick() {
        backend?.playSystemSound("Pop", 0.25f)
    }
}
