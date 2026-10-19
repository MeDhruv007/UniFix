import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_scaffold.dart';

/// First step of password reset (laid out like design screen 02).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(AuthPasswordResetRequested(_email.text));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(
            message:
                'The facilities office shares reset codes with you. Once you '
                'have one, set a new password below.',
          ),
          const SizedBox(height: 12),
          SubmitButton(label: 'Send reset code', onPressed: _submit),
          const SizedBox(height: 10),
          SecondaryPillButton(
            label: 'I have a reset code',
            onPressed: () => context.push(Routes.resetPassword),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FormHint('Enter the email you signed up with'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(hintText: 'College email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: Validators.email,
            ),
          ],
        ),
      ),
    );
  }
}
