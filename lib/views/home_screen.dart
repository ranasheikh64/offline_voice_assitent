import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:voice_assistent/controllers/voice_controller.dart';
import 'package:voice_assistent/controllers/chat_controller.dart';
import 'package:voice_assistent/utils/constants.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final VoiceController voiceController = Get.find<VoiceController>();
    final ChatController chatController = Get.find<ChatController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            center: Alignment.center,
            radius: 1.5,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(voiceController),
              Expanded(child: _buildChatList(chatController)),
              _buildListeningIndicator(voiceController),
              const SizedBox(height: 20),
              _buildMicButton(voiceController),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(VoiceController controller) {
    return FadeInDown(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hey Rana", style: AppTextStyles.heading),
                Text(
                  DateFormat('EEEE, MMM d').format(DateTime.now()),
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.battery_charging_full, color: AppColors.accent, size: 18),
                  const SizedBox(width: 5),
                  Text(controller.batteryLevel.value, style: AppTextStyles.caption),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(ChatController controller) {
    return Obx(() => ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: controller.messages.length,
      itemBuilder: (context, index) {
        final msg = controller.messages[index];
        final isUser = msg.type == MessageType.user;
        
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(maxWidth: Get.width * 0.75),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Text(
                msg.text,
                style: AppTextStyles.body.copyWith(
                  color: isUser ? Colors.white : AppColors.textHeading,
                ),
              ),
            ),
          ),
        );
      },
    ));
  }

  Widget _buildListeningIndicator(VoiceController controller) {
    return Obx(() => controller.isListening.value
        ? Column(
            children: [
              const SpinKitThreeBounce(
                color: AppColors.primary,
                size: 30.0,
              ),
              const SizedBox(height: 10),
              Text(
                controller.speechText.value,
                style: AppTextStyles.body.copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          )
        : const SizedBox(height: 50));
  }

  Widget _buildMicButton(VoiceController controller) {
    return Obx(() => GestureDetector(
      onTap: () => controller.toggleListening(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (controller.isListening.value)
            const SpinKitPulsingGrid(
              color: AppColors.primary,
              size: 150,
            ),
          Container(
            height: 85,
            width: 85,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 25,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Icon(
              controller.isListening.value ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    ));
  }
}
