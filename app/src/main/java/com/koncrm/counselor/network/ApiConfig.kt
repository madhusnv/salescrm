package com.koncrm.counselor.network

import com.koncrm.counselor.BuildConfig

object ApiConfig {
    // Debug default: uses adb reverse proxy (adb reverse tcp:4000 tcp:4000)
    val BASE_URL: String = BuildConfig.API_BASE_URL
}
