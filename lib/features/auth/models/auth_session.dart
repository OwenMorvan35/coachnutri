class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.createdAt,
    this.name,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String? name;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}
