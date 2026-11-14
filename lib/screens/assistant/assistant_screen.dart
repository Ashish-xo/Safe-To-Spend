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

  static const _suggestions = [
    'spent 250 on biryani yesterday',
    'set food budget to 3000',
    'warn me when I spend over 1500 on shopping',
    'start a 25000 phone goal',
    'how much did I spend on food this month?',
    'can I afford a 800 concert ticket?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(
      isUser: false,
      text: 'Hi! I\'m Sage, your money assistant.\n\nLog a transaction in plain '
          'English or ask me anything about your spending.',
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _thinking) return;
    if (preset == null) _controller.clear();
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C896), Color(0xFF08916A)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sage',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                      Text('AI money assistant · free & private',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary(isDark))),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Chat
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: _messages.length + (_thinking ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_thinking && i == _messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card(isDark),
                          borderRadius: BorderRadius.circular(18),
                          border: isDark ? Border.all(color: AppColors.darkDivider) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primaryGreen),
                            ),
                            const SizedBox(width: 10),
                            Text('thinking…',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary(isDark))),
                          ],
                        ),
                      ),
                    );
                  }
                  final m = _messages[i];
                  final isUser = m.isUser;
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.primaryGreen
                            : AppColors.card(isDark),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                        border: !isUser && isDark
                            ? Border.all(color: AppColors.darkDivider)
                            : null,
                        boxShadow: !isUser && !isDark
                            ? [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isUser
                              ? Colors.white
                              : AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Suggestion chips (only at start)
            if (_messages.length <= 1)
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final s in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: AppColors.card(isDark),
                          side: BorderSide(
                              color: isDark
                                  ? AppColors.darkDivider
                                  : AppColors.lightDivider),
                          label: Text(s,
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () => _send(s),
                        ),
                      ),
                  ],
                ),
              ),

            // Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask Sage or log a transaction…',
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: AppColors.primaryGreen, width: 1.4),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkCardElevated
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _send(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C896), Color(0xFF08916A)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_upward,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
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
