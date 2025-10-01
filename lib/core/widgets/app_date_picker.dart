import 'package:flutter/material.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime initialDate,
  Locale? locale,
}) {
  final baseTheme = Theme.of(context);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));

  return showDatePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDate: initialDate,
    locale: locale,
    builder: (_, child) {
      if (child == null) return const SizedBox.shrink();
      return Theme(
        data: baseTheme.copyWith(
          dialogTheme: baseTheme.dialogTheme.copyWith(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: shape,
            elevation: 6,
          ),
          datePickerTheme: baseTheme.datePickerTheme.copyWith(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: shape,
            elevation: 6,
          ),
          colorScheme: baseTheme.colorScheme.copyWith(
            surface: Colors.white,
            surfaceVariant: Colors.white,
            surfaceTint: Colors.transparent,
          ),
        ),
        child: child,
      );
    },
  );
}
