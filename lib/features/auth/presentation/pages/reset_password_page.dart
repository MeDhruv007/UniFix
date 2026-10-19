import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/ds/ds_access.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_scaffold.dart';

/// Second step of password reset: enter the reset code and a new password.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      AuthPasswordResetConfirmed(
        token: _token.text,
        newPassword: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev.formStatus != curr.formStatus &&
          curr.formStatus == AuthFormStatus.success,
      listener: (context, _) => context.go(Routes.login),
      child: AuthScaffold(
        title: 'Set a new password',
        footer: SubmitButton(label: 'Update password', onPressed: _submit),
        child: Form(
          key: _formKey,
          child: PlatformAutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormHint(
                  'Enter the reset code you received and choose a new '
                  'password',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _token,
                  decoration: const InputDecoration(hintText: 'Reset code'),
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the reset code.'
                      : null,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  hint: 'New password',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                ),
                const SizedBox(height: 8),
                const FieldHelper('8+ characters, one number'),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _confirm,
                  hint: 'Confirm new password',
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
