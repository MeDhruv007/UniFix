import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../bloc/auth_bloc.dart';

/// Shows auth messages (errors and confirmations) as snackbars.
class AuthMessageListener extends StatelessWidget {
  const AuthMessageListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          curr.message != null && prev.message != curr.message,
      listener: (context, state) {
        context.showSnack(
          state.message!,
          isError: state.formStatus == AuthFormStatus.failure,
        );
        context.read<AuthBloc>().add(const AuthMessageCleared());
      },
      child: child,
    );
  }
}

/// Layout for the pushed auth forms (design screen 02): circle back button
/// and centred title, the form, and a [footer] pinned to the bottom that
/// scrolls with the form when the keyboard is open.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.showBack = true,
  });

  final String title;
  final Widget child;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return AuthMessageListener(
      child: Scaffold(
        appBar: DsTopBar(title: title, showBack: showBack),
        body: SafeArea(
          top: false,
          child: FillScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              12,
              AppSizes.gutter,
              18,
            ),
            body: child,
            footer: footer,
          ),
        ),
      ),
    );
  }
}

/// Scrollable column that is at least as tall as the viewport, with
/// [footer] pushed to the bottom (like the design's `margin-top:auto`).
class FillScrollView extends StatelessWidget {
  const FillScrollView({
    super.key,
    required this.body,
    this.footer,
    this.padding = EdgeInsets.zero,
    this.maxWidth = 480,
  });

  final Widget body;
  final Widget? footer;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              minHeight: (constraints.maxHeight - padding.vertical).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Black pill bound to the auth form's submitting state.
class SubmitButton extends StatelessWidget {
  const SubmitButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final submitting = context.select((AuthBloc b) => b.state.isSubmitting);
    return PrimaryPillButton(
      label: label,
      busy: submitting,
      onPressed: onPressed,
    );
  }
}

/// Pill password field with a "Show" / "Hide" text toggle (design 01).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hint = 'Password',
    this.validator,
    this.autofillHints,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              _obscure ? 'Show' : 'Hide',
              semanticsLabel: _obscure ? 'Show password' : 'Hide password',
            ),
          ),
        ),
      ),
    );
  }
}

/// [AutofillGroup] on mobile only. On Flutter web, moving focus between
/// fields of an autofill group trips an engine assertion ("The DOM element
/// of this text editing strategy is not currently active") and the second
/// field stops taking input, so the group is skipped there.
class PlatformAutofillGroup extends StatelessWidget {
  const PlatformAutofillGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      kIsWeb ? child : AutofillGroup(child: child);
}

/// "Use your ADIT email"-style hint above a form.
class FormHint extends StatelessWidget {
  const FormHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
