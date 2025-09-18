/// Chat domain model representing a conversation entry.
enum Role { user, coach }

/// Immutable message data containing author, content, and timestamp.
class Message {
  const Message({
    required this.role,
    required this.content,
    required this.ts,
  });

  final Role role;
  final String content;
  final DateTime ts;
}
