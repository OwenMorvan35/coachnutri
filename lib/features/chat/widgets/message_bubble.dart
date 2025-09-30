import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/message.dart';
import '../../../ui/widgets/glass_container.dart';
import '../../../theme/app_theme.dart';

/// Visual representation of a chat message styled as a bubble.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  static const _coachAvatarAsset = 'assets/images/coach_avatar.png';
  static const double _coachAvatarRadius = 18;
  static const double _coachAvatarSpacing = 10;
  static const double _coachHorizontalPadding = 16;

  final Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<GlassTokens>()!;
    final isUser = message.role == Role.user;
    final textColor = isUser
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withOpacity(0.92);
    final timestamp = _formatTimestamp(message.ts);
    final borderRadius = BorderRadius.circular(18);

    final bubbleContent = Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          timestamp,
          style: theme.textTheme.labelSmall?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );

    final userDecoration = BoxDecoration(
      color: theme.colorScheme.onSurface.withOpacity(0.08),
      borderRadius: borderRadius,
      border: Border.all(color: tokens.glassStroke.withOpacity(0.25)),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final double bubbleMaxWidth = isUser
        ? screenWidth * 0.88
        : math.max(
            0.0,
            screenWidth -
                (_coachAvatarRadius * 2) -
                _coachAvatarSpacing -
                _coachHorizontalPadding,
          );
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
      child: isUser
          ? DecoratedBox(
              decoration: userDecoration,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: bubbleContent,
              ),
            )
          : GlassContainer(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: bubbleContent,
            ),
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: bubble,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoachAvatar(theme),
            const SizedBox(width: _coachAvatarSpacing),
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachAvatar(ThemeData theme) {
    return CircleAvatar(
      radius: _coachAvatarRadius,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      backgroundImage: const AssetImage(_coachAvatarAsset),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final hours = timestamp.hour.toString().padLeft(2, '0');
    final minutes = timestamp.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}
