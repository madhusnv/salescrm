package com.koncrm.counselor.recordings

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingStoreTest {
    @Test
    fun togglesConsentFlag() = runBlocking {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val store = RecordingStore(context)

        store.setConsentGranted(false)
        val initial = store.stateFlow().first()
        assertFalse(initial.consentGranted)

        store.setConsentGranted(true)
        val updated = store.stateFlow().first()
        assertTrue(updated.consentGranted)
    }
}
