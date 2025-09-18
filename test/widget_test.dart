import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coachnutri/core/session.dart';
import 'package:coachnutri/features/auth/models/auth_session.dart';
import 'package:coachnutri/main.dart';

Future<void> _setupScreenSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

AuthSession _buildFakeSession() {
  return AuthSession(
    token: 'test-token',
    user: AuthUser(
      id: 'user-123',
      email: 'user@example.com',
      name: 'Test',
      createdAt: DateTime.now(),
    ),
  );
}

void main() {
  testWidgets('Affiche la page auth quand aucune session', (tester) async {
    await _setupScreenSize(tester);
    final controller = SessionController();

    await tester.pumpWidget(CoachNutriApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Créer un compte'), findsNothing);
  });

  testWidgets(
    'CoachNutriApp démarre sur le coach avec message d’accueil quand session active',
    (tester) async {
      await _setupScreenSize(tester);
      final controller = SessionController()..setSession(_buildFakeSession());

      await tester.pumpWidget(CoachNutriApp(sessionController: controller));
      await tester.pumpAndSettle();

      expect(find.text('CoachNutri'), findsOneWidget);
      expect(
        find.text(
          "Bonjour ! Comment puis-je t'aider dans ton parcours nutrition aujourd'hui ?",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('La navigation permet d’afficher la section recettes', (
    tester,
  ) async {
    await _setupScreenSize(tester);
    final controller = SessionController()..setSession(_buildFakeSession());

    await tester.pumpWidget(CoachNutriApp(sessionController: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Recettes sur-mesure'), findsOneWidget);
    expect(find.text('Suivi du poids'), findsNothing);
  });
}
