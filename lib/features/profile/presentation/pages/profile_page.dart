import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/widgets/department_field.dart';
import '../bloc/profile_cubit.dart';

/// Account screen, shown as a tab in both shells and at `/profile`.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.embedded = false});

  /// True when shown as a bottom-nav tab (no back button).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    return BlocProvider(
      create: (_) => getIt<ProfileCubit>(),
      child: Scaffold(
        appBar: embedded ? null : const DsTopBar(title: 'Profile'),
        body: SafeArea(
          top: embedded,
          child: user == null
              ? const LoadingView()
              : BlocListener<ProfileCubit, ProfileState>(
                  listenWhen: (prev, next) => prev.status != next.status,
                  listener: (context, state) {
                    switch (state.status) {
                      case ProfileStatus.success:
                        context.showSnack('Profile updated.');
                        context.read<ProfileCubit>().acknowledge();
                      case ProfileStatus.failure:
                        context.showSnack(
                          state.message ?? 'Could not update your profile.',
                          isError: true,
                        );
                        context.read<ProfileCubit>().acknowledge();
                      case ProfileStatus.idle || ProfileStatus.saving:
                        break;
                    }
                  },
                  child: _ProfileBody(user: user, embedded: embedded),
                ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user, required this.embedded});

  final AppUser user;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.gutter,
        embedded ? 0 : 4,
        AppSizes.gutter,
        32,
      ),
      children: [
        if (embedded) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              header: true,
              child: const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _IdentityCard(user: user),
        const SizedBox(height: 24),
        const SectionLabel('Edit profile'),
        const SizedBox(height: 12),
        // Re-seed the form if the stored profile changes elsewhere.
        _ProfileForm(
          key: ValueKey('${user.uid}|${user.displayName}|${user.department}'),
          user: user,
        ),
        const SizedBox(height: 28),
        SecondaryPillButton(
          label: 'Sign out',
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthSignOutRequested()),
        ),
      ],
    );
  }
}

/// Avatar, name, email and role/department pills on a periwinkle card.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final department = user.department?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.periwinkle,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        children: [
          _AvatarButton(user: user),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textOnPeriwinkle,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              DsPill(
                label: user.isAdmin ? 'Facilities admin' : 'Student',
                background: user.isAdmin ? AppColors.ink : AppColors.white,
                foreground: user.isAdmin ? AppColors.white : AppColors.ink,
                large: true,
              ),
              DsPill(
                label: department.isEmpty ? 'No department set' : department,
                background: AppColors.white.withValues(alpha: 0.55),
                large: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The profile avatar with an edit badge; opens the preset picker.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.user});

  final AppUser user;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<ProfileCubit>();
    final picked = await showAvatarPicker(context, currentId: user.avatar);
    if (picked == null) return; // dismissed
    final id = picked.isEmpty ? null : picked;
    if (id == user.avatar) return;
    await cubit.setAvatar(id);
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.select((ProfileCubit c) => c.state.isSaving);
    return Semantics(
      button: true,
      label: 'Change avatar',
      child: InkWell(
        onTap: saving ? null : () => _pick(context),
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 80,
          child: Stack(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: UserAvatar(
                    avatarId: user.avatar,
                    name: user.displayName,
                    size: 72,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: saving
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(
                          Icons.edit,
                          size: 14,
                          color: AppColors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.user});

  final AppUser user;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.user.displayName,
  );
  late final TextEditingController _department = TextEditingController(
    text: widget.user.department ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _department.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<ProfileCubit>().updateProfile(
      displayName: _name.text,
      department: _department.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.select((ProfileCubit c) => c.state.isSaving);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: !saving,
            decoration: const InputDecoration(hintText: 'Name'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            maxLength: AppConstants.displayNameMaxLength,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            validator: Validators.displayName,
          ),
          const SizedBox(height: 12),
          DepartmentField(
            controller: _department,
            enabled: !saving,
            onSubmitted: _submit,
          ),
          const SizedBox(height: 16),
          PrimaryPillButton(
            label: 'Save changes',
            busy: saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
