import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_brand.dart';
import '../widgets/auth_scaffold.dart';

/// Design screen 01: periwinkle brand block, email + password, and the
/// "Sign in" / "Create an account" pills at the bottom.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      AuthSignInRequested(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthMessageListener(
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: FillScrollView(
            body: Form(
              key: _formKey,
              child: PlatformAutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandBlock(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(
                              hintText: 'College email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            controller: _password,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Password is required.'
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.push(Routes.forgotPassword),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SubmitButton(label: 'Sign in', onPressed: _submit),
                  const SizedBox(height: 10),
                  SecondaryPillButton(
                    label: 'Create an account',
                    onPressed: () => context.push(Routes.register),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
