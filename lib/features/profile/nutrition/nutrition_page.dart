import 'package:flutter/material.dart';

import 'package:coachnutri/core/widgets/app_date_picker.dart';
import '../../../core/session.dart';
import 'nutrition_api.dart';
import 'nutrition_profile.dart';

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _allergiesCtrl = TextEditingController();
  final TextEditingController _preferencesCtrl = TextEditingController();
  final TextEditingController _constraintsCtrl = TextEditingController();
  final TextEditingController _budgetCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();
  final TextEditingController _medicalCtrl = TextEditingController();

  NutritionApi? _api;
  NutritionProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  String _gender = 'UNSPECIFIED';
  String _goal = 'UNSPECIFIED';
  String _activityLevel = 'UNSPECIFIED';
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    final session = SessionScope.of(context, listen: false);
    _api = NutritionApi(tokenProvider: () => session.session?.token);
    _fetch();
  }

  @override
  void dispose() {
    _api?.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _allergiesCtrl.dispose();
    _preferencesCtrl.dispose();
    _constraintsCtrl.dispose();
    _budgetCtrl.dispose();
    _timeCtrl.dispose();
    _medicalCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final profile = await _api!.fetchProfile();
      _assignProfile(profile);
    } on NutritionApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Impossible de récupérer les informations.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _assignProfile(NutritionProfile profile) {
    _profile = profile;
    _gender = profile.gender;
    _goal = profile.goal;
    _activityLevel = profile.activityLevel;
    _birthDate = profile.birthDate;
    _heightCtrl.text = profile.heightCm?.toStringAsFixed(1) ?? '';
    _weightCtrl.text = profile.startingWeightKg?.toStringAsFixed(1) ?? '';
    _allergiesCtrl.text = profile.allergies.join(', ');
    _preferencesCtrl.text = profile.dietaryPreferences.join(', ');
    _constraintsCtrl.text = profile.constraints.join(', ');
    _budgetCtrl.text = profile.budgetConstraint ?? '';
    _timeCtrl.text = profile.timeConstraint ?? '';
    _medicalCtrl.text = profile.medicalConditions ?? '';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Santé & nutrition'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _sectionWrapper(
                    theme,
                    title: 'Profil santé',
                    children: [
                      _buildGenderField(theme),
                      const SizedBox(height: 12),
                      _buildBirthDateField(theme),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        controller: _heightCtrl,
                        label: 'Taille (cm)',
                        hint: 'Ex: 178',
                      ),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        controller: _weightCtrl,
                        label: 'Poids initial (kg)',
                        hint: 'Ex: 72.5',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionWrapper(
                    theme,
                    title: 'Objectifs & habitudes',
                    children: [
                      _buildGoalField(),
                      const SizedBox(height: 12),
                      _buildActivityField(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionWrapper(
                    theme,
                    title: 'Allergies & préférences',
                    children: [
                      _buildChipInput(
                        controller: _allergiesCtrl,
                        label: 'Allergies (séparées par des virgules)',
                        hint: 'Ex: arachides, gluten',
                      ),
                      const SizedBox(height: 12),
                      _buildChipInput(
                        controller: _preferencesCtrl,
                        label: 'Régimes / préférences',
                        hint: 'Ex: vegan, halal',
                      ),
                      const SizedBox(height: 12),
                      _buildChipInput(
                        controller: _constraintsCtrl,
                        label: 'Contraintes (budget, temps…) ',
                        hint: 'Ex: budget limité, préparation rapide',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionWrapper(
                    theme,
                    title: 'Autres informations',
                    children: [
                      _buildTextField(
                        controller: _budgetCtrl,
                        label: 'Budget (optionnel)',
                        maxLines: 1,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _timeCtrl,
                        label: 'Disponibilité temps (optionnel)',
                        maxLines: 1,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _medicalCtrl,
                        label: 'Conditions médicales',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                )
                              : const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _sectionWrapper(ThemeData theme,
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGenderField(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _gender,
      dropdownColor: Colors.white,
      items: NutritionProfile.genders.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _gender = value);
      },
      decoration: _inputDecoration('Sexe'),
    );
  }

  Widget _buildBirthDateField(ThemeData theme) {
    final text = _birthDate != null
        ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
        : 'Sélectionner une date';
    return InkWell(
      onTap: _pickBirthDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration('Date de naissance'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text),
            const Icon(Icons.calendar_today_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalField() {
    return DropdownButtonFormField<String>(
      value: _goal,
      dropdownColor: Colors.white,
      items: NutritionProfile.goals.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _goal = value);
      },
      decoration: _inputDecoration('Objectif'),
    );
  }

  Widget _buildActivityField() {
    return DropdownButtonFormField<String>(
      value: _activityLevel,
      dropdownColor: Colors.white,
      items: NutritionProfile.activityLevels.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _activityLevel = value);
      },
      decoration: _inputDecoration('Niveau d’activité'),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  Widget _buildChipInput({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 2,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(label),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final result = await showAppDatePicker(
      context: context,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      initialDate: initial,
      locale: const Locale('fr', 'FR'),
    );
    if (result != null) {
      setState(() => _birthDate = result);
    }
  }

  Future<void> _save() async {
    final height = _parseDouble(_heightCtrl.text);
    final weight = _parseDouble(_weightCtrl.text);

    if (height != null && (height < 80 || height > 260)) {
      _showError('La taille doit être comprise entre 80 et 260 cm.');
      return;
    }
    if (weight != null && (weight < 20 || weight > 400)) {
      _showError('Le poids doit être compris entre 20 et 400 kg.');
      return;
    }

    final payload = <String, dynamic>{
      'gender': _gender,
      'goal': _goal,
      'activityLevel': _activityLevel,
      if (_birthDate != null) 'birthDate': _birthDate!.toUtc().toIso8601String(),
      if (height != null) 'heightCm': height,
      if (weight != null) 'startingWeightKg': weight,
      'allergies': _parseList(_allergiesCtrl.text),
      'dietaryPreferences': _parseList(_preferencesCtrl.text),
      'constraints': _parseList(_constraintsCtrl.text),
      'budgetConstraint': _budgetCtrl.text.trim().isEmpty ? null : _budgetCtrl.text.trim(),
      'timeConstraint': _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
      'medicalConditions': _medicalCtrl.text.trim().isEmpty ? null : _medicalCtrl.text.trim(),
    };

    setState(() => _saving = true);
    try {
      final profile = await _api!.updateProfile(payload);
      _assignProfile(profile);
      _showMessage('Profil nutrition mis à jour.');
    } on NutritionApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Impossible de mettre à jour les informations.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _parseDouble(String value) {
    final sanitized = value.replaceAll(',', '.').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  List<String> _parseList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
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

  InputDecoration _inputDecoration(String label, {String? hint}) {
    final theme = Theme.of(context);
    const baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF424242), width: 1.4),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: baseBorder,
      enabledBorder: baseBorder,
      disabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }
}
