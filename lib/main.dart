import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:voice_assistent/controllers/voice_controller.dart';
import 'package:voice_assistent/views/home_screen.dart';
import 'package:voice_assistent/utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(VoiceController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Voice Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Outfit',
      ),
      home: const HomeScreen(),
    );
  }
}
