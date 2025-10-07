import 'package:coachnutri/core/widgets/app_date_picker.dart';
import 'package:flutter/material.dart';

class AddWeightSheetResult {
  const AddWeightSheetResult({
    required this.weightKg,
    required this.date,
    this.note,
  });

  final double weightKg;
  final DateTime date;
  final String? note;
}

class AddWeightSheet extends StatefulWidget {
  const AddWeightSheet._();

  static Future<AddWeightSheetResult?> show(BuildContext context) {
    return showModalBottomSheet<AddWeightSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddWeightSheet._(),
    );
  }

  @override
  State<AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends State<AddWeightSheet> {
  late final TextEditingController _weightController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weightController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    final dateLabel = _formatLongDate(_selectedDate);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Nouvelle mesure', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Poids (kg)',
                    hintText: 'Ex: 72,4',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: const Text('Date'),
                  subtitle: Text(dateLabel),
                  onTap: _pickDate,
                ),
                TextField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optionnel)',
                    hintText: 'Ex: après la séance de sport',
                  ),
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Enregistrer'),
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showAppDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: now,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
    );
    if (result != null) {
      setState(() {
        _selectedDate = result;
      });
    }
  }

  void _submit() {
    final rawWeight = _weightController.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(rawWeight);
    if (parsed == null) {
      setState(() => _error = 'Entre un poids valide.');
      return;
    }
    if (parsed < 20 || parsed > 400) {
      setState(() => _error = 'Le poids doit être entre 20 et 400 kg.');
      return;
    }

    final now = DateTime.now();
    final localDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
    );

    Navigator.of(context).pop(
      AddWeightSheetResult(
        weightKg: double.parse(parsed.toStringAsFixed(2)),
        date: localDate,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      ),
    );
  }
}

String _formatLongDate(DateTime date) {
  const weekdays = <int, String>{
    DateTime.monday: 'Lundi',
    DateTime.tuesday: 'Mardi',
    DateTime.wednesday: 'Mercredi',
    DateTime.thursday: 'Jeudi',
    DateTime.friday: 'Vendredi',
    DateTime.saturday: 'Samedi',
    DateTime.sunday: 'Dimanche',
  };
  const months = <int, String>{
    1: 'janvier',
    2: 'février',
    3: 'mars',
    4: 'avril',
    5: 'mai',
    6: 'juin',
    7: 'juillet',
    8: 'août',
    9: 'septembre',
    10: 'octobre',
    11: 'novembre',
    12: 'décembre',
  };
  final wd = weekdays[date.weekday] ?? '';
  final month = months[date.month] ?? '';
  return '$wd ${date.day} $month'.trim();
}
