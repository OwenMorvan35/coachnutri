import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/logger.dart';
import '../../core/session.dart';
import 'models/message.dart';
import 'widgets/message_bubble.dart';
import 'services/coach_api.dart';

/// Chat screen inspired by conversational assistants with mock AI responses.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Message> _messages = <Message>[];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  late final CoachApi _api;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final sessionController = SessionScope.of(context, listen: false);
    _api = CoachApi(tokenProvider: () => sessionController.session?.token);
    Logger.i('CHAT_PAGE', 'ChatPage initState');
    Logger.i('CHAT_PAGE', 'Coach API base URL: ${_api.baseUrl}');
    _messages.add(
      Message(
        role: Role.coach,
        content:
            "Bonjour ! Comment puis-je t'aider dans ton parcours nutrition aujourd'hui ?",
        ts: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    Logger.i('CHAT_PAGE', 'ChatPage dispose');
    _scrollController.dispose();
    _inputController.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              physics: const BouncingScrollPhysics(),
              separatorBuilder: (context, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(message: message);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildComposer(context),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets > 0 ? 8 : 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_isSending,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Dis-moi comment je peux t’aider…',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isSending
                  ? const SizedBox(
                      height: 26,
                      width: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : IconButton(
                      key: const ValueKey('send'),
                      onPressed: _handleSend,
                      icon: const Icon(Icons.send_rounded),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final rawInput = _inputController.text.trim();
    if (rawInput.isEmpty || _isSending) {
      return;
    }

    final List<Message> previousMessages = List<Message>.from(_messages);
    final userMessage = Message(
      role: Role.user,
      content: rawInput,
      ts: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });
    Logger.i('CHAT_SEND', 'User message sent: "$rawInput"');
    _inputController.clear();
    _scrollToBottom();
    FocusScope.of(context).unfocus();

    try {
      Logger.i('CHAT_REPLY', 'Calling coach API');
      final CoachResponse response = await _api.sendMessage(
        message: rawInput,
        history: _buildHistoryPayload(previousMessages),
      );

      if (!mounted) {
        return;
      }

      final coachMessage = Message(
        role: Role.coach,
        content: response.reply,
        ts: DateTime.now(),
      );

      setState(() {
        _messages.add(coachMessage);
        _isSending = false;
      });
      Logger.i(
        'CHAT_REPLY',
        'Coach API reply delivered (requestId: ${response.requestId ?? 'n/a'})',
      );
      _scrollToBottom();
    } on CoachApiException catch (error, stackTrace) {
      Logger.e(
        'CHAT_ERROR',
        'Coach API error: ${error.message}',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      Logger.e('CHAT_ERROR', 'Unexpected chat error', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une erreur est survenue, réessaie.')),
      );
    }
  }

  List<Map<String, String>> _buildHistoryPayload(List<Message> messages) {
    if (messages.isEmpty) {
      return const <Map<String, String>>[];
    }
    return messages
        .map(
          (message) => <String, String>{
            'role': message.role == Role.user ? 'user' : 'coach',
            'content': message.content,
          },
        )
        .toList(growable: false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      Logger.i('CHAT_SCROLL', 'Auto scroll to position $target');
      _scrollController
          .animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
          .catchError((Object error, StackTrace stackTrace) {
            Logger.e('CHAT_SCROLL', 'Scroll failed', error, stackTrace);
          });
    });
  }
}
