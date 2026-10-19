import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/ds/ds.dart';

/// Common ADIT departments offered in the department dropdown. The server
/// stores department as free text, so "Other" reveals a text field.
abstract final class AditDepartments {
  static const String other = 'Other';

  static const List<String> all = [
    'Automobile Engineering',
    'Civil Engineering',
    'Computer Engineering',
    'Electrical Engineering',
    'Electronics & Communication',
    'Food Processing Technology',
    'Information Technology',
    'Mechanical Engineering',
    'Applied Sciences & Humanities',
  ];
}

/// Dropdown pill of [AditDepartments] plus "Other" (free text). The chosen
/// department is kept in [controller]; empty means not set.
class DepartmentField extends StatefulWidget {
  const DepartmentField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  State<DepartmentField> createState() => _DepartmentFieldState();
}

class _DepartmentFieldState extends State<DepartmentField> {
  late String? _selected = _initialSelection(widget.controller.text.trim());

  static String? _initialSelection(String text) {
    if (text.isEmpty) return null;
    return AditDepartments.all.contains(text) ? text : AditDepartments.other;
  }

  static String? _validateOther(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your department.';
    if (v.length > AppConstants.displayNameMaxLength) {
      return 'Department must be at most '
          '${AppConstants.displayNameMaxLength} characters.';
    }
    return null;
  }

  void _onChanged(String? value) {
    setState(() => _selected = value);
    if (value == AditDepartments.other) {
      // Keep any custom text the user already typed.
      if (AditDepartments.all.contains(widget.controller.text)) {
        widget.controller.clear();
      }
    } else {
      widget.controller.text = value ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selected,
          isExpanded: true,
          onChanged: widget.enabled ? _onChanged : null,
          borderRadius: BorderRadius.circular(AppRadii.card),
          dropdownColor: AppColors.white,
          hint: const Text(
            'Department (optional)',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(20, 13, 13, 13),
          ),
          icon: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.white,
            ),
          ),
          items: [
            for (final d in [...AditDepartments.all, AditDepartments.other])
              DropdownMenuItem(
                value: d,
                child: Text(d, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        if (_selected == AditDepartments.other) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            decoration: const InputDecoration(hintText: 'Your department'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: AppConstants.displayNameMaxLength,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            validator: _validateOther,
            onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          ),
        ],
      ],
    );
  }
}
