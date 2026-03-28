package com.rana.voice_assistant.voice_assistent

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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

import io.flutter.plugin.common.EventChannel
import android.content.BroadcastReceiver

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.rana.voice_assistant/channel"
    private val EVENT_CHANNEL = "com.rana.voice_assistant/voice_event"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            // ... existing methods ...
            when (call.method) {
                "getBatteryLevel" -> {
                    val batteryLevel = getBatteryLevel()
                    if (batteryLevel != -1) result.success(batteryLevel)
                    else result.error("UNAVAILABLE", "Battery level not available.", null)
                }
                "toggleFlashlight" -> {
                    val status = call.argument<Boolean>("status") ?: false
                    toggleFlashlight(status)
                    result.success(null)
                }
                "setVolume" -> {
                    val percent = call.argument<Int>("percent") ?: 50
                    setVolume(percent)
                    result.success(null)
                }
                "toggleWifi" -> {
                    val status = call.argument<Boolean>("status") ?: false
                    toggleWifi(status)
                    result.success(null)
                }
                "toggleBluetooth" -> {
                    val status = call.argument<Boolean>("status") ?: false
                    val success = toggleBluetooth(status)
                    result.success(success)
                }
                "makeCall" -> {
                    val number = call.argument<String>("number") ?: ""
                    makeCall(number)
                    result.success(null)
                }
                "searchContact" -> {
                    val name = call.argument<String>("name") ?: ""
                    val contact = searchContact(name)
                    result.success(contact)
                }
                "setAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 0
                    val minute = call.argument<Int>("minute") ?: 0
                    setAlarm(hour, minute)
                    result.success(null)
                }
                "setTimer" -> {
                    val seconds = call.argument<Int>("seconds") ?: 0
                    setTimer(seconds)
                    result.success(null)
                }
                "openApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val success = openApp(packageName)
                    result.success(success)
                }
                "controlMedia" -> {
                    val action = call.argument<String>("action") ?: ""
                    controlMedia(action)
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
                else -> result.notImplemented()
            }
        }

        // EventChannel
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(voiceReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(voiceReceiver, filter)
        }
    }

    private val voiceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val text = intent?.getStringExtra("text")
            if (text != null) {
                eventSink?.success(text)
            }
        }
    }

    private fun startVoiceService() {
        val intent = Intent(this, VoiceService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopVoiceService() {
        val intent = Intent(this, VoiceService::class.java)
        stopService(intent)
    }

    private fun controlMedia(action: String) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val keyCode = when (action) {
            "play", "pause" -> android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "next" -> android.view.KeyEvent.KEYCODE_MEDIA_NEXT
            "previous" -> android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> -1
        }
        
        if (keyCode != -1) {
            val downIntent = android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, keyCode)
            audioManager.dispatchMediaKeyEvent(downIntent)
            
            val upIntent = android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, keyCode)
            audioManager.dispatchMediaKeyEvent(upIntent)
        }
    }

    private fun toggleBluetooth(status: Boolean): Boolean {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        return if (status) {
            bluetoothAdapter.enable()
        } else {
            bluetoothAdapter.disable()
        }
    }

    private fun makeCall(number: String) {
        val intent = Intent(Intent.ACTION_CALL)
        intent.data = android.net.Uri.parse("tel:$number")
        startActivity(intent)
    }

    private fun searchContact(name: String): String? {
        val contentResolver = contentResolver
        val cursor = contentResolver.query(
            android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            null,
            android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " LIKE ?",
            arrayOf("%$name%"),
            null
        )
        if (cursor != null && cursor.moveToFirst()) {
            val numberIndex = cursor.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER)
            val phone = cursor.getString(numberIndex)
            cursor.close()
            return phone
        }
        cursor?.close()
        return null
    }

    private fun setAlarm(hour: Int, minute: Int) {
        val intent = Intent(android.provider.AlarmClock.ACTION_SET_ALARM)
        intent.putExtra(android.provider.AlarmClock.EXTRA_HOUR, hour)
        intent.putExtra(android.provider.AlarmClock.EXTRA_MINUTES, minute)
        intent.putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, true)
        startActivity(intent)
    }

    private fun setTimer(seconds: Int) {
        val intent = Intent(android.provider.AlarmClock.ACTION_SET_TIMER)
        intent.putExtra(android.provider.AlarmClock.EXTRA_LENGTH, seconds)
        intent.putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, true)
        startActivity(intent)
    }

    private fun startBatteryMonitoring() {
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        registerReceiver(batteryReceiver, filter)
    }

    private val batteryReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            val batteryPct = level * 100 / scale.toFloat()
            
            // Send to Flutter if needed (e.g. via EventChannel or MethodChannel invoke)
            // For now we just check for critical levels and can notify
        }
    }

    private fun setVolume(percent: Int) {

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val volume = (maxVolume * percent) / 100
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
    }

    private fun toggleWifi(status: Boolean) {
        if (VERSION.SDK_INT < VERSION_CODES.Q) {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiManager.isWifiEnabled = status
        } else {
            // For Android 10+, users usually need to be prompted or use specialized APIs
            // Here we just attempt, though it might be restricted
            val intent = Intent(android.provider.Settings.Panel.ACTION_WIFI)
            startActivity(intent)
        }
    }

    private fun openApp(packageName: String): Boolean {
        val pm: PackageManager = packageManager
        return try {
            val intent = pm.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getBatteryLevel(): Int {
        val batteryLevel: Int
        if (VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            val intent = ContextWrapper(applicationContext).registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            batteryLevel = intent!!.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        }
        return batteryLevel
    }

    private fun toggleFlashlight(status: Boolean) {
        try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList[0]
            if (VERSION.SDK_INT >= VERSION_CODES.M) {
                cameraManager.setTorchMode(cameraId, status)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
