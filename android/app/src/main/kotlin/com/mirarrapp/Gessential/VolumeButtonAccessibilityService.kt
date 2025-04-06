package com.mirarrapp.Gessential

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

class VolumeButtonAccessibilityService : AccessibilityService() {
    
    companion object {
        // Constants for button detection
        private const val VOLUME_UP_KEY = KeyEvent.KEYCODE_VOLUME_UP
        private const val LONG_PRESS_DURATION = 1000 // milliseconds
        private const val ACTION_VOICE_NOTE = "action_voice_note"
    }
    
    // Variables to track volume button state
    private var isVolumeUpPressed = false
    private var volumeUpPressStartTime = 0L
    private val handler = Handler(Looper.getMainLooper())
    
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // We don't need to implement this for key event detection
    }
    
    override fun onInterrupt() {
        // Required by the AccessibilityService interface
    }
    
    override fun onKeyEvent(event: KeyEvent): Boolean {
        // Handle key events
        when (event.keyCode) {
            VOLUME_UP_KEY -> {
                when (event.action) {
                    KeyEvent.ACTION_DOWN -> {
                        // Volume up button is pressed
                        if (!isVolumeUpPressed) {
                            isVolumeUpPressed = true
                            volumeUpPressStartTime = System.currentTimeMillis()
                            
                            // Schedule a check for long press
                            handler.postDelayed({
                                val pressDuration = System.currentTimeMillis() - volumeUpPressStartTime
                                if (isVolumeUpPressed && pressDuration >= LONG_PRESS_DURATION) {
                                    // Long press detected, launch the app in voice note mode
                                    launchVoiceNoteMode()
                                }
                            }, LONG_PRESS_DURATION.toLong())
                        }
                        // Return false to allow the system to handle the normal volume up action
                        return false
                    }
                    KeyEvent.ACTION_UP -> {
                        // Volume up button is released
                        isVolumeUpPressed = false
                        // Return false to allow the system to handle the normal volume up action
                        return false
                    }
                }
            }
        }
        return false
    }
    
    private fun launchVoiceNoteMode() {
        // Create an intent to launch the main activity
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra("action", ACTION_VOICE_NOTE)
        }
        startActivity(intent)
        
        // Provide a slight feedback
        Toast.makeText(this, "Launching Voice Note", Toast.LENGTH_SHORT).show()
    }
} 