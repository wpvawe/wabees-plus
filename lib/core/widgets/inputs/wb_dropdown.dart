import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';

/// 🎯 DROPDOWN WIDGET
class WbDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final bool isRequired;
  final String? hint;

  const WbDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isRequired = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: AppDimens.xxs),
                Text(
                  '*',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimens.xs),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          hint: hint != null ? Text(hint!) : null,
          decoration: const InputDecoration(
            contentPadding: AppDimens.inputPadding,
          ),
          validator: isRequired
              ? (value) {
                  if (value == null) return '$label is required';
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}
