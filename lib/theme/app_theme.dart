import 'dart:ui';

import 'package:flutter/material.dart';

// ThemeExtension holding glassmorphism tokens
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.neutralSurface,
    required this.glassTint,
    required this.glassStroke,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.accentLilac,
    required this.textPrimary,
    required this.textSecondary,
    required this.blurStrong,
    required this.radius,
    required this.shadowColor,
  });

  final Color neutralSurface;
  final Color glassTint;
  final Color glassStroke;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color accentLilac;
  final Color textPrimary;
  final Color textSecondary;
  final double blurStrong; // 20
  final double radius; // 20
  final Color shadowColor; // soft shadow color

  LinearGradient get oceanic => LinearGradient(
        colors: [accentPrimary, accentSecondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get iris => LinearGradient(
        colors: [accentSecondary, accentLilac],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  GlassTokens copyWith({
    Color? neutralSurface,
    Color? glassTint,
    Color? glassStroke,
    Color? accentPrimary,
    Color? accentSecondary,
    Color? accentLilac,
    Color? textPrimary,
    Color? textSecondary,
    double? blurStrong,
    double? radius,
    Color? shadowColor,
  }) {
    return GlassTokens(
      neutralSurface: neutralSurface ?? this.neutralSurface,
      glassTint: glassTint ?? this.glassTint,
      glassStroke: glassStroke ?? this.glassStroke,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentLilac: accentLilac ?? this.accentLilac,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      blurStrong: blurStrong ?? this.blurStrong,
      radius: radius ?? this.radius,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  ThemeExtension<GlassTokens> lerp(ThemeExtension<GlassTokens>? other, double t) {
    if (other is! GlassTokens) return this;
    return GlassTokens(
      neutralSurface: Color.lerp(neutralSurface, other.neutralSurface, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassStroke: Color.lerp(glassStroke, other.glassStroke, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      accentLilac: Color.lerp(accentLilac, other.accentLilac, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      blurStrong: lerpDouble(blurStrong, other.blurStrong, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const tokens = GlassTokens(
      neutralSurface: Color(0xFFF7F8FA),
      // Match containers to the app background for a unified look
      glassTint: Color(0xFFF7F8FA),
      glassStroke: Color.fromRGBO(255, 255, 255, 0.55),
      accentPrimary: Color(0xFF4DA3FF),
      accentSecondary: Color(0xFF8AD3FF),
      accentLilac: Color(0xFFBCA7FF),
      textPrimary: Color(0xFF0B0C0F),
      textSecondary: Color.fromRGBO(11, 12, 15, 0.64),
      blurStrong: 20,
      radius: 20,
      shadowColor: Color(0x14000000),
    );

    final colorScheme = ColorScheme.light(
      primary: tokens.accentPrimary,
      secondary: tokens.accentSecondary,
      surface: tokens.neutralSurface,
      onSurface: tokens.textPrimary,
      onPrimary: Colors.white,
      // Remove grey outlines across the app
      outline: Colors.transparent,
      outlineVariant: Colors.transparent,
    );

    // “iOS 26” style text with SF Pro preference, falling back to Inter/system
    const fontStack = 'SF Pro, Inter, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif';

    final textTheme = const TextTheme(
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ).apply(
      bodyColor: tokens.textPrimary,
      displayColor: tokens.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontStack,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.neutralSurface,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
          borderSide: BorderSide(color: Colors.transparent, width: 0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
          borderSide: const BorderSide(color: Colors.transparent, width: 0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
          borderSide: BorderSide(color: tokens.accentPrimary, width: 2),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
      extensions: const <ThemeExtension<dynamic>>[tokens],
    );
  }
}
