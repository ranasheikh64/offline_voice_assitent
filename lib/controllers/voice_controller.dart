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
  var speechText = "শুরু করতে মাইকে চাপ দিন".obs;
  var responseText = "আমি আপনাকে কীভাবে সাহায্য করতে পারি?".obs;
  var batteryLevel = "০%".obs;
  
  final String assistantName = "Jasmin";

  final Map<String, String> appPackages = {
    'ইউটিউব': 'com.google.android.youtube',
    'হোয়াটসঅ্যাপ': 'com.whatsapp',
    'ফেসবুক': 'com.facebook.katana',
    'ইনস্টাগ্রাম': 'com.instagram.android',
    'ক্রোম': 'com.android.chrome',
    'ম্যাপ': 'com.google.android.apps.maps',
    'সেটিং': 'com.android.settings',
    'ক্যামেরা': 'com.android.camera',
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
        print("Background Voice: $text");
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
    await _tts.speak(text);
  }

  Future<void> startBackgroundService() async {
    try {
      await platform.invokeMethod('startVoiceService');
    } catch (e) {
      print("Error starting service: $e");
    }
  }

  Future<void> toggleListening() async {
    // In background mode, we don't need manual toggle as much, but we keep it
    if (isListening.value) {
      _speech.stop();
      isListening.value = false;
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) => print('STT Status: $status'),
        onError: (error) => print('STT Error: $error'),
      );
      
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
    if (cmd.contains("ব্যাটারি") || cmd.contains("চার্জ")) {
      _getBatteryLevel();
      speak("আপনার ফোনের চার্জ এখন ${batteryLevel.value}");
    } 
    // Flashlight
    else if (cmd.contains("লাইট") || cmd.contains("টর্চ") || cmd.contains("খোলো") || cmd.contains("জ্বালাও")) {
      bool turnOn = cmd.contains("জ্বালাও") || cmd.contains("খোলো") || cmd.contains("অন");
      _toggleFlashlight(turnOn);
      speak(turnOn ? "টর্চ জ্বালিয়েছি" : "টর্চ বন্ধ করেছি");
    } 
    // Time & Date
    else if (cmd.contains("সময়") || cmd.contains("কয়টা বাজে")) {
      String time = DateFormat('hh:mm a').format(DateTime.now());
      speak("এখন সময় $time");
    } else if (cmd.contains("তারিখ") || cmd.contains("আজ কি বার")) {
      String date = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
      speak("আজকের তারিখ $date");
    }
    // Volume
    else if (cmd.contains("ভলিউম") || cmd.contains("আওয়াজ")) {
      int volume = 50;
      RegExp regExp = RegExp(r"(\d+)");
      var match = regExp.firstMatch(cmd);
      if (match != null) {
        volume = int.parse(match.group(0)!);
      } else if (cmd.contains("ফুল") || cmd.contains("বাড়িয়ে দাও")) {
        volume = 100;
      } else if (cmd.contains("জিরো") || cmd.contains("কমিয়ে দাও")) {
        volume = 0;
      }
      _setVolume(volume);
      speak("ভলিউম $volume percent করা হয়েছে");
    }
    // WiFi
    else if (cmd.contains("ওয়াইফাই") || cmd.contains("ওয়াই-ফাই")) {
      bool turnOn = cmd.contains("চালু") || cmd.contains("অন");
      _toggleWifi(turnOn);
      speak("ওয়াইফাই সেটিংস খোলা হয়েছে");
    }
    // Bluetooth
    else if (cmd.contains("ব্লুটুথ")) {
      bool turnOn = cmd.contains("চালু") || cmd.contains("অন");
      _toggleBluetooth(turnOn);
      speak(turnOn ? "ব্লুটুথ চালু করেছি" : "ব্লুটুথ বন্ধ করেছি");
    }
    // Call & Contacts
    else if (cmd.contains("কল") || cmd.contains("ফোন")) {
      String name = cmd.replaceAll("কল", "").replaceAll("ফোন", "").replaceAll("দাও", "").trim();
      if (name.isNotEmpty) {
        _handleCallCommand(name);
      } else {
        speak("কাকে কল করতে হবে?");
      }
    }
    // Alarm
    else if (cmd.contains("অ্যালার্ম")) {
      _handleAlarmCommand(cmd);
    }
    // Timer
    else if (cmd.contains("টাইমার")) {
      _handleTimerCommand(cmd);
    }
    // Media Control
    else if (cmd.contains("গান") || cmd.contains("চালান") || cmd.contains("থামান") || cmd.contains("পরের")) {
      String action = "";
      if (cmd.contains("চালান") || cmd.contains("গান")) action = "play";
      if (cmd.contains("থামান") || cmd.contains("বন্ধ")) action = "pause";
      if (cmd.contains("পরের")) action = "next";
      _controlMedia(action);
      speak(action == "play" ? "গান চালু করছি" : "গান বন্ধ করছি");
    }
    // App Control
    else if (cmd.contains("খুলো") || cmd.contains("চালু করো")) {
      bool appFound = false;
      appPackages.forEach((name, package) {
        if (cmd.contains(name)) {
          _launchApp(package, name);
          appFound = true;
        }
      });
      if (!appFound) {
        speak("দুঃখিত, আমি এই অ্যাপটি খুঁজে পাইনি");
      }
    }
    // Smart Responses
    else if (cmd.contains("কেমন আছো") || cmd.contains("কেমন আছ")) {
      speak("আমি ভালো আছি, আপনি কেমন আছেন?");
    } else if (cmd.contains("তোমার নাম কি") || cmd.contains("নাম কি")) {
      speak("আমার নাম $assistantName, আমি আপনার ভয়েস অ্যাসিস্ট্যান্ট");
    } else if (cmd.contains("হ্যালো") || cmd.contains("হাই")) {
      speak("হ্যালো! আমি আপনাকে কীভাবে সাহায্য করতে পারি?");
    } else {
      // Background recognition can be noisy, so we only speak if it looks like a real command
      // Or if the app is in foreground
    }
  }

  Future<void> _handleAlarmCommand(String cmd) async {
    RegExp regExp = RegExp(r"(\d+)");
    var matches = regExp.allMatches(cmd);
    if (matches.isNotEmpty) {
      int hour = int.parse(matches.first.group(0)!);
      int minute = matches.length > 1 ? int.parse(matches.elementAt(1).group(0)!) : 0;
      
      try {
        await platform.invokeMethod('setAlarm', {"hour": hour, "minute": minute});
        speak("$hour টা $minute মিনিটের জন্য অ্যালার্ম সেট করেছি");
      } catch (e) {
        speak("অ্যালার্ম সেট করতে সমস্যা হয়েছে");
      }
    } else {
      speak("অনুগ্রহ করে সময় বলুন");
    }
  }

  Future<void> _handleTimerCommand(String cmd) async {
    RegExp regExp = RegExp(r"(\d+)");
    var match = regExp.firstMatch(cmd);
    if (match != null) {
      int value = int.parse(match.group(0)!);
      int seconds = value * 60; // Assuming minutes
      
      try {
        await platform.invokeMethod('setTimer', {"seconds": seconds});
        speak("$value মিনিটের টাইমার সেট করেছি");
      } catch (e) {
         speak("টাইমার সেট করতে সমস্যা হয়েছে");
      }
    }
  }

  Future<void> _handleCallCommand(String name) async {
    try {
      final String? number = await platform.invokeMethod('searchContact', {"name": name});
      if (number != null) {
        speak("$name কে কল করছি");
        await platform.invokeMethod('makeCall', {"number": number});
      } else {
        speak("আপনার কন্টাক্টে $name কে খুঁজে পাওয়া যায়নি");
      }
    } catch (e) {
       speak("কল করতে সমস্যা হয়েছে");
    }
  }

  Future<void> _getBatteryLevel() async {
    try {
      final int result = await platform.invokeMethod('getBatteryLevel');
      batteryLevel.value = "$result%";
    } on PlatformException {
      batteryLevel.value = "অজানাঁ";
    }
  }

  Future<void> _toggleFlashlight(bool turnOn) async {
    try {
      await platform.invokeMethod('toggleFlashlight', {"status": turnOn});
    } catch (e) {}
  }

  Future<void> _setVolume(int percent) async {
    try {
      await platform.invokeMethod('setVolume', {"percent": percent});
    } catch (e) {}
  }

  Future<void> _toggleWifi(bool turnOn) async {
    try {
      await platform.invokeMethod('toggleWifi', {"status": turnOn});
    } catch (e) {}
  }

  Future<void> _toggleBluetooth(bool turnOn) async {
    try {
      await platform.invokeMethod('toggleBluetooth', {"status": turnOn});
    } catch (e) {}
  }

  Future<void> _controlMedia(String action) async {
    try {
      await platform.invokeMethod('controlMedia', {"action": action});
    } catch (e) {}
  }

  Future<void> _launchApp(String packageName, String appName) async {
    try {
      await platform.invokeMethod('openApp', {"packageName": packageName});
      speak("$appName খুলছি");
    } catch (e) {}
  }
}
