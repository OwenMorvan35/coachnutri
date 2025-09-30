import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session.dart';
import '../../auth/models/auth_session.dart';
import 'identity_api.dart';
import 'identity_profile.dart';

class IdentityPage extends StatefulWidget {
  const IdentityPage({super.key});

  @override
  State<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends State<IdentityPage> {
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  IdentityApi? _api;
  IdentityProfile? _profile;

  bool _loading = true;
  bool _savingProfile = false;
  bool _updatingAvatar = false;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    final controller = SessionScope.of(context, listen: false);
    _api = IdentityApi(tokenProvider: () => controller.session?.token);
    _load();
  }

  @override
  void dispose() {
    _api?.dispose();
    _displayNameCtrl.dispose();
    _nameCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _api!.fetchProfile();
      _applyProfile(profile);
    } on IdentityApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Impossible de récupérer le profil.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyProfile(IdentityProfile profile) {
    _profile = profile;
    _displayNameCtrl.text = profile.displayName ?? '';
    _nameCtrl.text = profile.name ?? '';
    _syncSession(profile);
    if (mounted) {
      setState(() {});
    }
  }

  void _syncSession(IdentityProfile profile) {
    final controller = SessionScope.of(context, listen: false);
    final session = controller.session;
    if (session == null) return;
    final updatedUser = session.user.copyWith(
      name: profile.name,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
      updatedAt: profile.updatedAt,
    );
    controller.updateUser(updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon identité'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _buildAvatarSection(theme),
                  const SizedBox(height: 24),
                  _buildIdentityForm(theme),
                  const SizedBox(height: 32),
                  _buildSecuritySection(theme),
                  const SizedBox(height: 32),
                  _buildLogoutButton(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection(ThemeData theme) {
    final avatar = _profile?.avatarUrl;
    final avatarProvider = avatar != null && avatar.isNotEmpty
        ? NetworkImage(avatar)
        : null;
    final initials = (_profile?.displayName ?? _profile?.name ?? _profile?.email ?? 'U')
        .trim()
        .isNotEmpty
        ? (_profile?.displayName ?? _profile?.name ?? _profile?.email ?? 'U')[0].toUpperCase()
        : 'U';

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      initials,
                      style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 2,
              child: FilledButton.tonal(
                onPressed: _updatingAvatar ? null : _showAvatarSourceSheet,
                child: _updatingAvatar
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_rounded, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _profile?.displayName ?? 'Ton profil',
          style: theme.textTheme.titleMedium,
        ),
        if (_profile?.email != null) ...[
          const SizedBox(height: 4),
          Text(
            _profile!.email,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _buildIdentityForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Informations', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _displayNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Pseudo',
            hintText: 'Ex: Alex Coach',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nom complet (optionnel)',
          ),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          child: Text(_profile?.email ?? ''),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _savingProfile ? null : _saveProfile,
            child: _savingProfile
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Enregistrer'),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sécurité', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _currentPasswordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mot de passe actuel',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nouveau mot de passe',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirmer le nouveau mot de passe',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _changingPassword ? null : _changePassword,
            child: _changingPassword
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Modifier mon mot de passe'),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return FilledButton.tonalIcon(
      onPressed: _logout,
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Se déconnecter'),
    );
  }

  Future<void> _saveProfile() async {
    final displayName = _displayNameCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (displayName.isEmpty) {
      _showError('Merci de renseigner un pseudo.');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final profile = await _api!.updateProfile(
        displayName: displayName,
        name: name.isNotEmpty ? name : null,
      );
      _applyProfile(profile);
      _showMessage('Profil mis à jour.');
    } on IdentityApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Impossible de mettre à jour le profil.');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _showAvatarSourceSheet() async {
    if (!mounted) return;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAvatar(ImageSource.camera);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.close_rounded, color: theme.colorScheme.error),
              title: Text(
                'Annuler',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mimeType = await file.mimeType ?? 'image/jpeg';
      final filename = file.name.isNotEmpty ? file.name : 'avatar.jpg';
      await _uploadAvatar(bytes, filename, mimeType);
    } catch (error) {
      _showError('Impossible de sélectionner la photo.');
    }
  }

  Future<void> _uploadAvatar(Uint8List bytes, String filename, String mimeType) async {
    setState(() => _updatingAvatar = true);
    try {
      final profile = await _api!.uploadAvatar(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
      _applyProfile(profile);
      _showMessage('Photo mise à jour.');
    } on IdentityApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Impossible de mettre à jour la photo.');
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordCtrl.text.trim();
    final next = _newPasswordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _showError('Merci de renseigner tous les champs.');
      return;
    }
    if (next != confirm) {
      _showError('Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() => _changingPassword = true);
    try {
      await _api!.changePassword(currentPassword: current, newPassword: next);
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _showMessage('Mot de passe mis à jour.');
    } on IdentityApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Impossible de modifier le mot de passe.');
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _logout() {
    final controller = SessionScope.of(context, listen: false);
    controller.clearSession();
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
