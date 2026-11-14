import 'package:flutter/material.dart';
import '../../services/app_store.dart';
import '../../services/chat_assistant.dart';
import '../../theme/app_theme.dart';

/// AI Assistant chat screen ("Sage"). Can answer questions about your
/// data and log transactions from natural language.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(
      isUser: false,
      text: 'Hi! I\'m Sage, your money assistant. 💚\n\n'
          'Try:\n'
          '• "spent 250 on biryani yesterday"\n'
          '• "how much did I spend on food this month?"\n'
          '• "log 5000 salary"\n'
          '• "can I afford a 800 concert ticket?"',
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMsg(isUser: true, text: text));
      _thinking = true;
    });
    _scrollDown();

    final reply = await ChatAssistant(AppStore()).handle(text);
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _messages.add(_ChatMsg(isUser: false, text: reply.text));
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Sage — AI Money Assistant', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                  )),
                  const Spacer(),
                  Text('FREE • PRIVATE', style: TextStyle(
                    fontSize: 10, letterSpacing: 1,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  )),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _messages.length + (_thinking ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_thinking && i == _messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                            ),
                            const SizedBox(width: 8),
                            Text('thinking...', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          ]),
                        ),
                      ),
                    );
                  }
                  final m = _messages[i];
                  return Align(
                    alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: m.isUser
                            ? AppColors.primaryGreen
                            : (isDark ? Colors.grey[850] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: m.isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask Sage or log a transaction...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors.primaryGreen,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: _send,
                      ),
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
}

class _ChatMsg {
  final bool isUser;
  final String text;
  _ChatMsg({required this.isUser, required this.text});
}
