class NutritionProfile {
  const NutritionProfile({
    required this.id,
    required this.userId,
    this.gender = 'UNSPECIFIED',
    this.birthDate,
    this.heightCm,
    this.startingWeightKg,
    this.goal = 'UNSPECIFIED',
    this.activityLevel = 'UNSPECIFIED',
    this.allergies = const <String>[],
    this.dietaryPreferences = const <String>[],
    this.constraints = const <String>[],
    this.budgetConstraint,
    this.timeConstraint,
    this.medicalConditions,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String gender;
  final DateTime? birthDate;
  final double? heightCm;
  final double? startingWeightKg;
  final String goal;
  final String activityLevel;
  final List<String> allergies;
  final List<String> dietaryPreferences;
  final List<String> constraints;
  final String? budgetConstraint;
  final String? timeConstraint;
  final String? medicalConditions;
  final DateTime? updatedAt;

  NutritionProfile copyWith({
    String? gender,
    DateTime? birthDate,
    double? heightCm,
    double? startingWeightKg,
    String? goal,
    String? activityLevel,
    List<String>? allergies,
    List<String>? dietaryPreferences,
    List<String>? constraints,
    String? budgetConstraint,
    String? timeConstraint,
    String? medicalConditions,
    DateTime? updatedAt,
  }) {
    return NutritionProfile(
      id: id,
      userId: userId,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      startingWeightKg: startingWeightKg ?? this.startingWeightKg,
      goal: goal ?? this.goal,
      activityLevel: activityLevel ?? this.activityLevel,
      allergies: allergies ?? this.allergies,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      constraints: constraints ?? this.constraints,
      budgetConstraint: budgetConstraint ?? this.budgetConstraint,
      timeConstraint: timeConstraint ?? this.timeConstraint,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NutritionProfile.fromJson(Map<String, dynamic> json) {
    return NutritionProfile(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      gender: (json['gender'] as String?) ?? 'UNSPECIFIED',
      birthDate: json['birthDate'] != null ? DateTime.tryParse(json['birthDate'] as String) : null,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      startingWeightKg: (json['startingWeightKg'] as num?)?.toDouble(),
      goal: (json['goal'] as String?) ?? 'UNSPECIFIED',
      activityLevel: (json['activityLevel'] as String?) ?? 'UNSPECIFIED',
      allergies: ((json['allergies'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      dietaryPreferences: ((json['dietaryPreferences'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      constraints: ((json['constraints'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      budgetConstraint: json['budgetConstraint'] as String?,
      timeConstraint: json['timeConstraint'] as String?,
      medicalConditions: json['medicalConditions'] as String?,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  static const genders = <String, String>{
    'FEMALE': 'Femme',
    'MALE': 'Homme',
    'OTHER': 'Autre',
    'UNSPECIFIED': 'Non précisé',
  };

  static const goals = <String, String>{
    'LOSE': 'Perte de poids',
    'MAINTAIN': 'Maintien',
    'GAIN': 'Prise de poids',
    'UNSPECIFIED': 'Non précisé',
  };

  static const activityLevels = <String, String>{
    'SEDENTARY': 'Sédentaire',
    'LIGHT': 'Léger',
    'MODERATE': 'Modéré',
    'ACTIVE': 'Actif',
    'VERY_ACTIVE': 'Très actif',
    'UNSPECIFIED': 'Non précisé',
  };
}
