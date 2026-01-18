package com.koncrm.counselor.network

object ApiConfig {
    // Using adb reverse proxy: adb reverse tcp:4000 tcp:4000
    // This forwards device's localhost:4000 to host's localhost:4000
    const val BASE_URL = "http://127.0.0.1:4000"
    
    // Production URL - switch to this for release
    // const val BASE_URL = "https://api.example.com"
}
