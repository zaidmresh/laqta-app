import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/db_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ChatScreen extends StatefulWidget {
  final AppState appState;
  const ChatScreen({super.key, required this.appState});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    final conversationId = widget.appState.activeConversationId;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (text.isEmpty || conversationId == null || uid == null || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await DbService.instance.sendMessage(conversationId: conversationId, senderUid: uid, text: text);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذّر إرسال الرسالة، حاول مرة أخرى')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final conversationId = appState.activeConversationId;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (conversationId == null || uid == null) {
      return const Center(child: Text('المحادثة غير متوفرة'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => appState.go(AppView.messages, push: false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.sandLine),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.chevron_right, size: 18, color: AppColors.tealDark),
                ),
              ),
              const SizedBox(width: 10),
              NameAvatar(name: appState.activeConversationTitle, size: 34),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appState.activeConversationTitle, style: AppTextStyles.heading(size: 14.5)),
                    Text(appState.activeConversationProductTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(size: 10.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DbService.instance.watchMessages(conversationId),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const [];
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return Center(
                  child: Text('ابدأ المحادثة الآن',
                      style: AppTextStyles.body(size: 12.5, color: AppColors.inkSoft)),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final isMe = m['sender_uid'] == uid;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.teal : AppColors.card,
                        border: isMe ? null : Border.all(color: AppColors.sandLine),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        m['text'] as String? ?? '',
                        style: AppTextStyles.body(size: 12.5, color: isMe ? AppColors.white : AppColors.ink),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.sandLine),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        border: InputBorder.none,
                      ),
                      style: AppTextStyles.body(size: 13),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.send, size: 18, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
