import 'package:flutter/widgets.dart';

import '../features/auth/models/auth_session.dart';
import 'session_storage.dart';

class SessionController extends ChangeNotifier {
  SessionController({SessionStorage? storage}) : _storage = storage ?? SessionStorage();

  final SessionStorage _storage;
  AuthSession? _session;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;

  void setSession(AuthSession session) {
    _session = session;
    _storage.save(session);
    notifyListeners();
  }

  void clearSession() {
    _session = null;
    _storage.clear();
    notifyListeners();
  }
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required this.controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  final SessionController controller;

  static SessionController of(BuildContext context, {bool listen = true}) {
    SessionScope? scope;
    if (listen) {
      scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    } else {
      final element = context
          .getElementForInheritedWidgetOfExactType<SessionScope>();
      scope = element?.widget as SessionScope?;
    }
    if (scope == null) {
      throw StateError('SessionScope non trouvé dans le widget tree');
    }
    return scope.controller;
  }

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      controller != oldWidget.controller;
}
