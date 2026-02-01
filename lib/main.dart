import 'dart:async' show Timer;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' show SpeechToText;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xffF5F7FB),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final SpeechToText speech = SpeechToText();
  final AudioPlayer player = AudioPlayer();

  bool listening = false;
  final List<Map<String, String>> messages = [];
  bool streaming = false;

  void scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    });
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || streaming) return;

    setState(() {
      messages.add({"role": "user", "text": text});
      messages.add({
        "role": "ai",
        "text": "",
        "audio": "",
        "playing": "false",
        "isvoiceprocessing": "true",
      });
      streaming = true;
    });

    controller.clear();
    scrollDown();

    final request = http.Request(
      "POST",
      Uri.parse(
        "https://c62110d25f81.ngrok-free.app/chat-stream",
      ), // use ngrok when remote
    );

    request.headers["Content-Type"] = "application/json";

    request.body = jsonEncode({
      "messages": messages.sublist(0, messages.length - 1),
    });

    final response = await request.send();
    response.stream
        .transform(utf8.decoder)
        .listen(
          (chunk) {
            final lines = chunk.split("\n");

            for (var line in lines) {
              if (line.trim().isEmpty) continue;

              final data = jsonDecode(line);

              if (data["type"] == "text") {
                setState(() {
                  messages.last["text"] = messages.last["text"]! + data["data"];
                });
              }

              if (data["type"] == "voice_processing") {
                var id = data["id"];
                String? messageText = messages.last["text"];
                setState(() {
                  messages.last["isvoiceprocessing"] = "true";
                });
                Timer.periodic(Duration(seconds: 3), (timer) async {
                  final res = await http.get(
                    Uri.parse(
                      "https://c62110d25f81.ngrok-free.app/voice-status/$id",
                    ),
                  );

                  final data = jsonDecode(res.body);

                  if (data["ready"] == true) {
                    setState(() {
                      int messageIndex = messages.indexWhere(
                        (msg) =>
                            msg["text"] == messageText && msg["role"] == "ai",
                      );
                      messages[messageIndex]["isvoiceprocessing"] = "false";
                      timer.cancel();
                      messages[messageIndex]["audio"] =
                          "https://c62110d25f81.ngrok-free.app/audio/${data["file"]}";
                    });
                  }
                });
              }
            }

            scrollDown();
          },
          onDone: () {
            setState(() => streaming = false);
          },
        );
  }

  Future<void> toggleAudio(int index) async {
    final msg = messages[index];

    if (msg["playing"] == "true") {
      await player.stop();

      setState(() {
        msg["playing"] = "false";
      });
    } else {
      await player.stop();
      String audioUrl = msg["audio"] ?? "";
      await player.play(UrlSource(audioUrl));

      setState(() {
        for (var m in messages) {
          m["playing"] = "false";
        }
        msg["playing"] = "true";
      });

      player.onPlayerComplete.listen((_) {
        setState(() {
          msg["playing"] = "false";
        });
      });
    }
  }

  // Widget chatBubble(String text, bool isUser) {
  //   return Align(
  //     alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
  //     child: Container(
  //       margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
  //       padding: const EdgeInsets.all(14),
  //       constraints: const BoxConstraints(maxWidth: 300),
  //       decoration: BoxDecoration(
  //         gradient: isUser
  //             ? const LinearGradient(
  //                 colors: [Color(0xff4facfe), Color(0xff00f2fe)],
  //               )
  //             : null,
  //         color: isUser ? null : Colors.white,
  //         borderRadius: BorderRadius.circular(18),
  //         boxShadow: [
  //           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
  //         ],
  //       ),
  //       child: Text(
  //         text.isEmpty && !isUser ? "Typing..." : text,
  //         style: TextStyle(
  //           color: isUser ? Colors.white : Colors.black87,
  //           fontSize: 15,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget chatBubble(Map msg, int index) {
    final isUser = msg["role"] == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                msg["text"],
                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
              ),
            ),

            if (!isUser)
              GestureDetector(
                onTap: () => toggleAudio(index),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (msg["isvoiceprocessing"] == "true")
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      Icon(
                        msg["playing"] == "true"
                            ? Icons.volume_off
                            : Icons.volume_up,
                        size: 24,
                        color: msg["playing"] == "true"
                            ? Colors.grey
                            : Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget inputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.1)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              listening ? Icons.mic_off : Icons.mic,
              color: listening ? Colors.red : Colors.blue,
            ),
            onPressed: () {
              listening ? stopVoice() : startVoice();
            },
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Ask something...",
                border: InputBorder.none,
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> startVoice() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() => listening = true);

      speech.listen(
        onResult: (result) {
          setState(() {
            if (result.finalResult) {
              listening = false;
              controller.text = result.recognizedWords;
              sendMessage();
            }
          });
        },
      );
    }
  }

  void stopVoice() {
    speech.stop();
    setState(() => listening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text("OpenSource AI"),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: messages.length,
              itemBuilder: (c, i) {
                final m = messages[i];
                return chatBubble(messages[i], i);
              },
            ),
          ),
          inputBar(),
        ],
      ),
    );
  }
}
