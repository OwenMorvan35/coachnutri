import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/logger.dart';
import '../../core/session.dart';
import 'models/message.dart';
import 'widgets/message_bubble.dart';
import '../../ui/widgets/glass_container.dart';
import '../../theme/app_theme.dart';
import '../../ui/widgets/water_drop_button.dart';
import 'services/coach_api.dart';
import 'services/chat_hooks.dart';
import '../auth/models/auth_session.dart';
import '../weight/services/weight_api.dart';
import '../weight/services/weight_repository.dart';

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
  late final WeightApi _weightApi;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final sessionController = SessionScope.of(context, listen: false);
    _api = CoachApi(tokenProvider: () => sessionController.session?.token);
    _weightApi = WeightApi(tokenProvider: () => sessionController.session?.token);
    Logger.i('CHAT_PAGE', 'ChatPage initState');
    Logger.i('CHAT_PAGE', 'Coach API base URL: ${_api.baseUrl}');
    _seedOrLoadHistory();
  }

  @override
  void dispose() {
    Logger.i('CHAT_PAGE', 'ChatPage dispose');
    _scrollController.dispose();
    _inputController.dispose();
    _api.dispose();
    _weightApi.dispose();
    super.dispose();
  }

  Future<void> _seedOrLoadHistory() async {
    try {
      final history = await _api.fetchHistory(limit: 30);
      if (!mounted) return;
      setState(() {
        if (history.isNotEmpty) {
          _messages
            ..clear()
            ..addAll(history);
        } else {
          _messages.add(
            Message(
              role: Role.coach,
              content:
                  "Bonjour ! Comment puis-je t'aider dans ton parcours nutrition aujourd'hui ?",
              ts: DateTime.now(),
            ),
          );
        }
      });
      // Ensure we land on the latest messages after initial load
      _scrollToBottom();
    } on CoachApiException catch (e) {
      Logger.w('CHAT_HISTORY', 'History unavailable: ${e.message}');
      if (!mounted) return;
      setState(() {
        _messages.add(
          Message(
            role: Role.coach,
            content:
                "Bonjour ! Comment puis-je t'aider dans ton parcours nutrition aujourd'hui ?",
            ts: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    } catch (e, st) {
      Logger.e('CHAT_HISTORY', 'Failed to load history', e, st);
      if (!mounted) return;
      setState(() {
        _messages.add(
          Message(
            role: Role.coach,
            content:
                "Bonjour ! Comment puis-je t'aider dans ton parcours nutrition aujourd'hui ?",
            ts: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).extension<GlassTokens>()?.neutralSurface,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 32),
                  itemCount: _messages.length,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (context, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return MessageBubble(message: message);
                  },
                ),
              ),
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
      child: GlassContainer(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_isSending,
                textCapitalization: TextCapitalization.sentences,
                textAlignVertical: TextAlignVertical.center,
                style: Theme.of(context).textTheme.bodyLarge,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Dis-moi comment je peux t’aider…',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                      ),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  isDense: false,
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
                  : WaterDropButton(
                      key: const ValueKey('send'),
                      onPressed: _handleSend,
                      child: const Icon(Icons.send_rounded, size: 18),
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
      final handledByWeight = await _maybeHandleWeightCommand(rawInput);
      if (handledByWeight) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }
      Logger.i('CHAT_REPLY', 'Calling coach API');
      final CoachResponse response = await _api.sendMessage(
        message: rawInput,
        history: _buildHistoryPayload(previousMessages),
      );

      if (!mounted) {
        return;
      }

      // Strip any structured JSON (ACTIONS...) from the visible reply
      final cleaned = _stripStructuredJson(response.reply);

      setState(() {
        _messages.add(Message(role: Role.coach, content: cleaned, ts: DateTime.now()));
        _isSending = false;
      });
      Logger.i(
        'CHAT_REPLY',
        'Coach API reply delivered (requestId: ${response.requestId ?? 'n/a'})',
      );
      _scrollToBottom();

      // Handle optional structured payloads from the LLM reply
      try {
        final session = SessionScope.of(context, listen: false).session;
        final userId = session?.user.id ?? '';
        final tokenProvider = () => session?.token;
        final obj = ChatHooks.tryParseStructuredPayload(response.reply);
        final type = (obj?['type'] as String? ?? '').trim();
        if (userId.isNotEmpty && obj != null && type.isNotEmpty) {
          if (type == 'recipe_batch') {
            final List<dynamic> raws = (obj['recipes'] as List?) ?? const [];
            final titles = raws
                .whereType<Map<String, dynamic>>()
                .map((e) => (e['title'] as String? ?? '').trim())
                .where((t) => t.isNotEmpty)
                .toList(growable: false);
            final count = titles.length;
            final accepted = await _confirmAddRecipes(context, count, titles.take(3).toList());
            if (accepted == true) {
              ChatHooks.processStructuredPayloadFromReply(
                reply: response.reply,
                userId: userId,
                tokenProvider: tokenProvider,
              );
            }
          } else if (type == 'shopping_list_update') {
            // Apply shopping ops silently (no popup), but without showing JSON in chat
            ChatHooks.processStructuredPayloadFromReply(
              reply: response.reply,
              userId: userId,
              tokenProvider: tokenProvider,
            );
          }
        }
      } catch (error, stackTrace) {
        Logger.e('CHAT_HOOK', 'Failed to process structured payload', error, stackTrace);
      }
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

  Future<bool> _maybeHandleWeightCommand(String text) async {
    if (!_looksLikeWeightCommand(text)) {
      return false;
    }
    try {
      final response = await _weightApi.logViaNlp(text);
      WeightRepository.instance.applyServerEntry(response.entry);
      if (!mounted) return true;
      setState(() {
        _messages.add(
          Message(role: Role.coach, content: response.message, ts: DateTime.now()),
        );
      });
      return true;
    } on WeightApiException catch (error) {
      if (error.statusCode == 400) {
        return false;
      }
      if (!mounted) return true;
      setState(() {
        _messages.add(
          Message(
            role: Role.coach,
            content: error.message,
            ts: DateTime.now(),
          ),
        );
      });
      return true;
    } catch (error, stackTrace) {
      Logger.e('CHAT_WEIGHT', 'Failed to log weight command', error, stackTrace);
      if (!mounted) return true;
      setState(() {
        _messages.add(
          Message(
            role: Role.coach,
            content: 'Oups, je n\'ai pas pu enregistrer la mesure. Réessaie dans un instant.',
            ts: DateTime.now(),
          ),
        );
      });
      return true;
    }
  }

  bool _looksLikeWeightCommand(String text) {
    final lower = text.toLowerCase();
    final weightPattern = RegExp(r'\b\d{2,3}(?:[\.,]\d{1,2})?\s*(kg|kilogrammes?|kilos?)');
    if (!weightPattern.hasMatch(lower)) {
      return false;
    }
    final datePattern = RegExp(
      r"(\d{1,2}[\/-]\d{1,2}(?:[\/-]\d{2,4})?|\b(hier|aujourd'hui|avant[-\s]?hier|demain|\d{1,2}\s+\p{L}+))",
      unicode: true,
    );
    return datePattern.hasMatch(lower);
  }

  String _stripStructuredJson(String reply) {
    final text = reply;
    final upper = text.toUpperCase();
    final idx = upper.indexOf('ACTIONS');
    if (idx >= 0) {
      // Cut everything from the label to the end
      final before = text.substring(0, idx).trimRight();
      return before.isEmpty ? '👍 Reçu.' : before;
    }
    // Fallback: try to drop trailing JSON object if it starts after some text
    final startObj = text.indexOf('{');
    if (startObj > 20) {
      return text.substring(0, startObj).trimRight();
    }
    return text;
  }

  Future<bool?> _confirmAddRecipes(BuildContext context, int count, List<String> sampleTitles) async {
    final theme = Theme.of(context);
    final preview = sampleTitles.isEmpty ? '' : '\n• ' + sampleTitles.join('\n• ');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter à Mes recettes ?'),
        content: Text(
          count <= 1
              ? 'Ajouter cette recette à Mes recettes ?$preview'
              : 'Ajouter $count recettes à Mes recettes ?$preview',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ajouter')),
        ],
      ),
    );
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

  void _scrollToBottom({int attempt = 0}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) {
        if (attempt < 5) {
          Future.delayed(const Duration(milliseconds: 40), () => _scrollToBottom(attempt: attempt + 1));
        }
        return;
      }
      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() < 4) {
        return;
      }
      Logger.i('CHAT_SCROLL', 'Auto scroll attempt $attempt to $target');
      _scrollController
          .animateTo(
            target,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .catchError((Object error, StackTrace stackTrace) {
            Logger.e('CHAT_SCROLL', 'Scroll failed', error, stackTrace);
          });
    });
  }
}
