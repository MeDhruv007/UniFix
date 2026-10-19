import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/ds/ds_access.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/department_field.dart';

/// Design screen 02.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _department = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _department, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final department = _department.text.trim();
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        displayName: _name.text,
        email: _email.text,
        password: _password.text,
        department: department.isEmpty ? null : department,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Note: there is deliberately no role selector. Every account is
    // created as a student; admins are provisioned out-of-band.
    return AuthScaffold(
      title: 'Create account',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(
            message:
                'New accounts are student accounts. Facilities access is set '
                'up by the college.',
          ),
          const SizedBox(height: 12),
          SubmitButton(label: 'Create account', onPressed: _submit),
        ],
      ),
      child: Form(
        key: _formKey,
        child: PlatformAutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormHint('Use your ADIT email'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Full name'),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: Validators.displayName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(hintText: 'College email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              DepartmentField(controller: _department),
              const SizedBox(height: 12),
              PasswordField(
                controller: _password,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: Validators.password,
              ),
              const SizedBox(height: 8),
              const FieldHelper('8+ characters, one number'),
              const SizedBox(height: 12),
              PasswordField(
                controller: _confirm,
                hint: 'Confirm password',
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v != _password.text ? 'Passwords do not match.' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
