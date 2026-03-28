import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:voice_assistent/controllers/chat_controller.dart';

class VoiceController extends GetxController {
  static const platform = MethodChannel('com.rana.voice_assistant/channel');
  static const eventChannel = EventChannel('com.rana.voice_assistant/voice_event');
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ChatController chatController = Get.put(ChatController());
  
  var isListening = false.obs;
  var alwaysListening = true.obs;
  var speechText = "শুরু করতে মাইকে চাপ দিন / Press mic to start".obs;
  var responseText = "জেসমিন আপনার সহায়তায় প্রস্তুত / Jasmin is ready to help".obs;
  var batteryLevel = "০% / 0%".obs;
  
  final String assistantName = "Jasmin";

  final Map<String, String> appPackages = {
    'youtube': 'com.google.android.youtube',
    'ইউটিউব': 'com.google.android.youtube',
    'whatsapp': 'com.whatsapp',
    'হোয়াটসঅ্যাপ': 'com.whatsapp',
    'facebook': 'com.facebook.katana',
    'ফেসবুক': 'com.facebook.katana',
    'instagram': 'com.instagram.android',
    'ইনস্টাগ্রাম': 'com.instagram.android',
    'chrome': 'com.android.chrome',
    'ক্রোম': 'com.android.chrome',
    'maps': 'com.google.android.apps.maps',
    'ম্যাপ': 'com.google.android.apps.maps',
    'settings': 'com.android.settings',
    'সেটিং': 'com.android.settings',
    'camera': 'com.android.camera',
    'ক্যামেরা': 'com.android.camera',
    'music': 'com.google.android.music',
    'গান': 'com.google.android.music',
  };

  @override
  void onInit() {
    super.onInit();
    _initTts();
    _getBatteryLevel();
    _initBackgroundListener();
    requestAllPermissions().then((_) {
      if (alwaysListening.value) {
        startBackgroundService();
      }
    });
  }

  void _initBackgroundListener() {
    eventChannel.receiveBroadcastStream().listen((text) {
      if (text != null && text.toString().isNotEmpty) {
        chatController.addMessage(text.toString(), MessageType.user);
        _processCommand(text.toString());
      }
    });
  }

  Future<void> requestAllPermissions() async {
    await [
      Permission.microphone,
      Permission.contacts,
      Permission.phone,
      Permission.camera,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.notification,
    ].request();
  }

  void _initTts() {
    _tts.setLanguage("bn-BD");
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    chatController.addMessage(text, MessageType.assistant);
    responseText.value = text;
    // Autodetect language for better TTS
    if (RegExp(r'[a-zA-Z]').hasMatch(text)) {
      await _tts.setLanguage("en-US");
    } else {
      await _tts.setLanguage("bn-BD");
    }
    await _tts.speak(text);
  }

  Future<void> startBackgroundService() async {
    try {
      await platform.invokeMethod('startVoiceService');
    } catch (e) {}
  }

  Future<void> toggleListening() async {
    if (isListening.value) {
      _speech.stop();
      isListening.value = false;
    } else {
      bool available = await _speech.initialize();
      if (available) {
        isListening.value = true;
        _speech.listen(
          localeId: "bn_BD",
          onResult: (result) {
            speechText.value = result.recognizedWords;
            if (result.finalResult) {
              isListening.value = false;
              chatController.addMessage(result.recognizedWords, MessageType.user);
              _processCommand(result.recognizedWords);
            }
          },
        );
      }
    }
  }

  void _processCommand(String command) {
    String cmd = command.toLowerCase();
    
    // Battery
    if (cmd.contains("battery") || cmd.contains("ব্যাটারি") || cmd.contains("চার্জ")) {
      _getBatteryLevel();
      speak("ব্যাটারি লেভেল ${batteryLevel.value} / Battery is ${batteryLevel.value}");
    } 
    // Flashlight
    else if (cmd.contains("torch") || cmd.contains("flashlight") || cmd.contains("লাইট") || cmd.contains("জ্বালাও")) {
      bool turnOn = cmd.contains("on") || cmd.contains("jalao") || cmd.contains("জ্বালাও") || cmd.contains("চালু");
      _toggleFlashlight(turnOn);
      speak(turnOn ? "লাইট জ্বালিয়েছি / Flashlight ON" : "লাইট বন্ধ করেছি / Flashlight OFF");
    } 
    // Vibrate
    else if (cmd.contains("vibrate") || cmd.contains("ভাইব্রেট") || cmd.contains("কাঁপা")) {
      _vibrate();
      speak("ভাইব্রেট করছি / Vibrating");
    }
    // Screen Control
    else if (cmd.contains("screen on") || cmd.contains("স্ক্রিন অন") || cmd.contains("আলো জ্বালাও")) {
      _turnScreenOn();
      speak("স্ক্রিন অন করেছি / Screen ON");
    }
    else if (cmd.contains("unlock") || cmd.contains("আনলক") || cmd.contains("তালা খোলো")) {
      _unlockPhone();
      speak("আনলক করার চেষ্টা করছি / Attempting to unlock");
    }
    // Time & Date
    else if (cmd.contains("time") || cmd.contains("সময়") || cmd.contains("বাজে")) {
      String time = DateFormat('hh:mm a').format(DateTime.now());
      speak("এখন $time / It's $time");
    } else if (cmd.contains("date") || cmd.contains("today") || cmd.contains("তারিখ")) {
      String date = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
      speak("আজ $date / Today is $date");
    }
    // Volume
    else if (cmd.contains("volume") || cmd.contains("ভলিউম") || cmd.contains("আওয়াজ")) {
      int volume = 50;
      RegExp regExp = RegExp(r"(\d+)");
      var match = regExp.firstMatch(cmd);
      if (match != null) volume = int.parse(match.group(0)!);
      else if (cmd.contains("full") || cmd.contains("maximum") || cmd.contains("ফুল")) volume = 100;
      else if (cmd.contains("mute") || cmd.contains("zero") || cmd.contains("বন্ধ")) volume = 0;
      
      _setVolume(volume);
      speak("ভলিউম $volume% করা হয়েছে / Volume set to $volume%");
    }
    // WiFi
    else if (cmd.contains("wifi") || cmd.contains("ওয়াইফাই")) {
      _toggleWifi(cmd.contains("on") || cmd.contains("চালু"));
      speak("ওয়াইফাই সেটিংস / WiFi Settings");
    }
    // Bluetooth
    else if (cmd.contains("bluetooth") || cmd.contains("ব্লুটুথ")) {
      bool turnOn = cmd.contains("on") || cmd.contains("চালু");
      _toggleBluetooth(turnOn);
      speak(turnOn ? "ব্লুটুথ চালু করেছি / Bluetooth ON" : "ব্লুটুথ বন্ধ করেছি / Bluetooth OFF");
    }
    // Call & Contacts
    else if (cmd.contains("call") || cmd.contains("কল") || cmd.contains("ফোন")) {
      String name = cmd.replaceAll("call", "").replaceAll("কল", "").replaceAll("ফোন", "").replaceAll("দাও", "").trim();
      if (name.isNotEmpty) _handleCallCommand(name);
      else speak("কাকে কল দেব? / Who to call?");
    }
    // Alarm
    else if (cmd.contains("alarm") || cmd.contains("অ্যালার্ম")) {
      _handleAlarmCommand(cmd);
    }
    // Timer
    else if (cmd.contains("timer") || cmd.contains("টাইমার")) {
      _handleTimerCommand(cmd);
    }
    // Media Control
    else if (cmd.contains("play") || cmd.contains("pause") || cmd.contains("next") || cmd.contains("previous") || 
             cmd.contains("গান") || cmd.contains("চালান") || cmd.contains("থামান")) {
      String action = "";
      if (cmd.contains("play") || cmd.contains("চালান") || cmd.contains("গান")) action = "play";
      if (cmd.contains("pause") || cmd.contains("থামান") || cmd.contains("বন্ধ")) action = "pause";
      if (cmd.contains("next") || cmd.contains("পরের")) action = "next";
      if (cmd.contains("previous") || cmd.contains("আগের")) action = "previous";
      
      if (action.isNotEmpty) {
        _controlMedia(action);
        speak("$action করছি / $action media");
      }
    }
    // App Control
    else if (cmd.contains("open") || cmd.contains("খুলো") || cmd.contains("চালু করো")) {
      bool appFound = false;
      appPackages.forEach((name, package) {
        if (cmd.contains(name)) {
          _launchApp(package, name);
          appFound = true;
        }
      });
      if (!appFound) speak("অ্যাপটি খুঁজে পাইনি / App not found");
    }
    // Smart Responses
    else if (cmd.contains("kemon aso") || cmd.contains("কেমন আছো")) {
      speak("আমি ভালো আছি, আপনি কেমন আছেন? / I'm good, how about you?");
    } else if (cmd.contains("name") || cmd.contains("নাম")) {
      speak("আমার নাম জেসমিন / My name is Jasmin");
    } else if (cmd.contains("hello") || cmd.contains("হাই")) {
      speak("হ্যালো! / Hello!");
    }
  }

  Future<void> _vibrate() async { await platform.invokeMethod('vibrate'); }
  Future<void> _turnScreenOn() async { await platform.invokeMethod('turnScreenOn'); }
  Future<void> _unlockPhone() async { await platform.invokeMethod('unlockPhone'); }

  Future<void> _handleAlarmCommand(String cmd) async {
    RegExp regExp = RegExp(r"(\d+)");
    var matches = regExp.allMatches(cmd);
    if (matches.isNotEmpty) {
      int hour = int.parse(matches.first.group(0)!);
      int minute = matches.length > 1 ? int.parse(matches.elementAt(1).group(0)!) : 0;
      await platform.invokeMethod('setAlarm', {"hour": hour, "minute": minute});
      speak("অ্যালার্ম সেট করেছি / Alarm set for $hour:$minute");
    }
  }

  Future<void> _handleTimerCommand(String cmd) async {
    RegExp regExp = RegExp(r"(\d+)");
    var match = regExp.firstMatch(cmd);
    if (match != null) {
      int seconds = int.parse(match.group(0)!) * 60;
      await platform.invokeMethod('setTimer', {"seconds": seconds});
      speak("টাইমার সেট করেছি / Timer set");
    }
  }

  Future<void> _handleCallCommand(String name) async {
    try {
      final String? number = await platform.invokeMethod('searchContact', {"name": name});
      if (number != null) {
        speak("$name কে কল দিচ্ছি / Calling $name");
        await platform.invokeMethod('makeCall', {"number": number});
      } else speak("$name কন্টাক্টে নেই / $name not in contacts");
    } catch (e) {}
  }

  Future<void> _getBatteryLevel() async {
    try {
      final int result = await platform.invokeMethod('getBatteryLevel');
      batteryLevel.value = "$result%";
    } catch (e) {}
  }

  Future<void> _toggleFlashlight(bool turnOn) async { await platform.invokeMethod('toggleFlashlight', {"status": turnOn}); }
  Future<void> _setVolume(int percent) async { await platform.invokeMethod('setVolume', {"percent": percent}); }
  Future<void> _toggleWifi(bool turnOn) async { await platform.invokeMethod('toggleWifi', {"status": turnOn}); }
  Future<void> _toggleBluetooth(bool turnOn) async { await platform.invokeMethod('toggleBluetooth', {"status": turnOn}); }
  Future<void> _controlMedia(String action) async { await platform.invokeMethod('controlMedia', {"action": action}); }
  Future<void> _launchApp(String packageName, String appName) async { await platform.invokeMethod('openApp', {"packageName": packageName}); }
}
