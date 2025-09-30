class IdentityProfile {
  const IdentityProfile({
    required this.id,
    required this.email,
    required this.createdAt,
    this.name,
    this.displayName,
    this.avatarUrl,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String? name;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  IdentityProfile copyWith({
    String? name,
    String? displayName,
    String? avatarUrl,
    DateTime? updatedAt,
  }) {
    return IdentityProfile(
      id: id,
      email: email,
      createdAt: createdAt,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory IdentityProfile.fromJson(Map<String, dynamic> json) {
    return IdentityProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
