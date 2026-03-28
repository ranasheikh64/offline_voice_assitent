package com.rana.voice_assistant.voice_assistent

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.bluetooth.BluetoothAdapter
import android.content.pm.PackageManager
import android.content.BroadcastReceiver
import android.app.KeyguardManager
import android.os.PowerManager
import android.os.Vibrator
import android.os.VibrationEffect

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.rana.voice_assistant/channel"
    private val EVENT_CHANNEL = "com.rana.voice_assistant/voice_event"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getBatteryLevel" -> result.success(getBatteryLevel())
                "toggleFlashlight" -> {
                    toggleFlashlight(call.argument<Boolean>("status") ?: false)
                    result.success(null)
                }
                "setVolume" -> {
                    setVolume(call.argument<Int>("percent") ?: 50)
                    result.success(null)
                }
                "toggleWifi" -> {
                    toggleWifi(call.argument<Boolean>("status") ?: false)
                    result.success(null)
                }
                "toggleBluetooth" -> {
                    result.success(toggleBluetooth(call.argument<Boolean>("status") ?: false))
                }
                "makeCall" -> {
                    makeCall(call.argument<String>("number") ?: "")
                    result.success(null)
                }
                "searchContact" -> result.success(searchContact(call.argument<String>("name") ?: ""))
                "setAlarm" -> {
                    setAlarm(call.argument<Int>("hour") ?: 0, call.argument<Int>("minute") ?: 0)
                    result.success(null)
                }
                "setTimer" -> {
                    setTimer(call.argument<Int>("seconds") ?: 0)
                    result.success(null)
                }
                "openApp" -> result.success(openApp(call.argument<String>("packageName") ?: ""))
                "controlMedia" -> {
                    controlMedia(call.argument<String>("action") ?: "")
                    result.success(null)
                }
                "startVoiceService" -> {
                    startVoiceService()
                    result.success(null)
                }
                "stopVoiceService" -> {
                    stopVoiceService()
                    result.success(null)
                }
                "vibrate" -> {
                    vibrate()
                    result.success(null)
                }
                "turnScreenOn" -> {
                    turnScreenOn()
                    result.success(null)
                }
                "unlockPhone" -> {
                    unlockPhone()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
        registerVoiceReceiver()
    }

    private fun registerVoiceReceiver() {
        val filter = IntentFilter("com.rana.voice_assistant.VOICE_TEXT")
        if (VERSION.SDK_INT >= VERSION_CODES.TIRAMISU) {
            registerReceiver(voiceReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(voiceReceiver, filter)
        }
    }

    private val voiceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.getStringExtra("text")?.let { eventSink?.success(it) }
        }
    }

    private fun startVoiceService() {
        val intent = Intent(this, VoiceService::class.java)
        if (VERSION.SDK_INT >= VERSION_CODES.O) startForegroundService(intent) else startService(intent)
    }

    private fun stopVoiceService() {
        stopService(Intent(this, VoiceService::class.java))
    }

    private fun vibrate() {
        val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (VERSION.SDK_INT >= VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            v.vibrate(500)
        }
    }

    private fun turnScreenOn() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP, "Jasmin:WakeLock")
        wl.acquire(3000)
        if (VERSION.SDK_INT >= VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    private fun unlockPhone() {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (VERSION.SDK_INT >= VERSION_CODES.O) {
            km.requestDismissKeyguard(this, null)
        }
    }

    private fun controlMedia(action: String) {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val keyCode = when (action) {
            "play", "pause" -> android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "next" -> android.view.KeyEvent.KEYCODE_MEDIA_NEXT
            "previous" -> android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> -1
        }
        if (keyCode != -1) {
            am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, keyCode))
            am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, keyCode))
        }
    }

    private fun toggleBluetooth(status: Boolean): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        return if (status) adapter.enable() else adapter.disable()
    }

    private fun makeCall(number: String) {
        val intent = Intent(Intent.ACTION_CALL, android.net.Uri.parse("tel:$number"))
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun searchContact(name: String): String? {
        val cursor = contentResolver.query(
            android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            null,
            "${android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
            arrayOf("%$name%"),
            null
        )
        cursor?.use {
            if (it.moveToFirst()) {
                return it.getString(it.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER))
            }
        }
        return null
    }

    private fun setAlarm(hour: Int, minute: Int) {
        val intent = Intent(android.provider.AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(android.provider.AlarmClock.EXTRA_HOUR, hour)
            putExtra(android.provider.AlarmClock.EXTRA_MINUTES, minute)
            putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, "Jasmin Alarm")
            putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun setTimer(seconds: Int) {
        val intent = Intent(android.provider.AlarmClock.ACTION_SET_TIMER).apply {
            putExtra(android.provider.AlarmClock.EXTRA_LENGTH, seconds)
            putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun setVolume(percent: Int) {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        am.setStreamVolume(AudioManager.STREAM_MUSIC, (max * percent) / 100, 0)
    }

    private fun toggleWifi(status: Boolean) {
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        if (VERSION.SDK_INT < VERSION_CODES.Q) {
            wm.isWifiEnabled = status
        } else {
            val intent = Intent(android.provider.Settings.Panel.ACTION_WIFI)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        }
    }

    private fun openApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                true
            } else false
        } catch (e: Exception) { false }
    }

    private fun getBatteryLevel(): Int {
        return if (VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
            (getSystemService(Context.BATTERY_SERVICE) as BatteryManager).getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            intent?.let { it.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / it.getIntExtra(BatteryManager.EXTRA_SCALE, -1) } ?: -1
        }
    }

    private fun toggleFlashlight(status: Boolean) {
        try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            if (VERSION.SDK_INT >= VERSION_CODES.M) cm.setTorchMode(cm.cameraIdList[0], status)
        } catch (e: Exception) {}
    }
}
