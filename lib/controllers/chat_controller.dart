import 'package:get/get.dart';

enum MessageType { user, assistant }

class ChatMessage {
  final String text;
  final MessageType type;
  final DateTime time;

  ChatMessage({required this.text, required this.type, required this.time});
}

class ChatController extends GetxController {
  var messages = <ChatMessage>[].obs;

  void addMessage(String text, MessageType type) {
    messages.insert(0, ChatMessage(
      text: text,
      type: type,
      time: DateTime.now(),
    ));
  }
}
