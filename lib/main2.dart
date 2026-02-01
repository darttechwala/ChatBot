import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ChatPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  final SpeechToText speech = SpeechToText();

  bool isStreaming = false;

  Future<void> sendMessage() async {
    final userMsg = controller.text.trim();
    if (userMsg.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": userMsg});
      messages.add({"role": "ai", "text": ""});
    });

    controller.clear();

    final request = http.Request(
      "POST",
      Uri.parse("https://c62110d25f81.ngrok-free.app/chat-stream"),
    );

    request.headers["Content-Type"] = "application/json";

    request.body = jsonEncode({
      "messages": messages.sublist(0, messages.length - 1),
    });

    final response = await request.send();

    response.stream.transform(utf8.decoder).listen((chunk) {
      setState(() {
        messages.last["text"] = messages.last["text"]! + chunk;
      });
    });
  }

  Widget bubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: isUser ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Future<void> startListening() async {
    bool available = await speech.initialize();
    if (available) {
      speech.listen(
        onResult: (result) {
          if (result.finalResult == true) {
            controller.text = result.recognizedWords;
            sendMessage();
          }
        },
      );
    }
  }

  void stopListening() {
    speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OpenSource AI Chat")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (c, i) {
                final msg = messages[i];
                return bubble(msg["text"]!, msg["role"] == "user");
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "Type message...",
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              IconButton(icon: Icon(Icons.mic), onPressed: startListening),

              IconButton(
                icon: const Icon(Icons.send),
                onPressed: isStreaming ? null : sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
