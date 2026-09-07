package com.leah.honeycomb

import android.app.Application

class HoneycombApplication : Application() {
    lateinit var container: AppContainer

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}

