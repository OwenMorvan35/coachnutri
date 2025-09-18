import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/logger.dart';
import '../../core/session.dart';
import 'models/auth_session.dart';
import 'services/auth_api.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  late final AuthApi _api;

  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = AuthApi();
  }

  @override
  void dispose() {
    _api.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRegisterMode ? 'Créer un compte' : 'Connexion',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegisterMode
                          ? 'Rejoins CoachNutri pour un suivi personnalisé.'
                          : 'Retrouve tes recommandations nutritionnelles.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: _isRegisterMode
                          ? TextInputAction.next
                          : TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    if (_isRegisterMode) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Prénom (optionnel)',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _handleSubmit,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : Icon(
                              _isRegisterMode
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.login_rounded,
                            ),
                      label: Text(
                        _isRegisterMode ? 'Créer mon compte' : 'Me connecter',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _toggleMode,
                        child: Text(
                          _isRegisterMode
                              ? 'Déjà un compte ? Se connecter'
                              : 'Nouveau sur CoachNutri ? Créer un compte',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _error = null;
    });
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Merci de renseigner email et mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    FocusScope.of(context).unfocus();

    try {
      AuthSession session;
      if (_isRegisterMode) {
        Logger.i('AUTH', 'Registering user $email');
        session = await _api.register(
          email: email,
          password: password,
          name: name,
        );
      } else {
        Logger.i('AUTH', 'Logging in user $email');
        session = await _api.login(email: email, password: password);
      }

      if (!mounted) {
        return;
      }

      SessionScope.of(context, listen: false).setSession(session);
    } on AuthApiException catch (error, stackTrace) {
      Logger.e(
        'AUTH_ERROR',
        'Auth API error: ${error.message}',
        error,
        stackTrace,
      );
      setState(() {
        _error = error.message;
      });
    } catch (error, stackTrace) {
      Logger.e('AUTH_ERROR', 'Unexpected auth error', error, stackTrace);
      setState(() {
        _error = 'Une erreur est survenue. Réessaie plus tard.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
