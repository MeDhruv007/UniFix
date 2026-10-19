import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/ds/ds_access.dart';
import '../../domain/entities/app_user.dart';
import '../bloc/auth_bloc.dart';

/// Design screen 16: shown when a student opens an admin route.
class NoAccessPage extends StatelessWidget {
  const NoAccessPage({super.key});

  void _home(BuildContext context) => context.go(Routes.home);

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    return Scaffold(
      appBar: DsTopBar(
        onBack: () => context.canPop() ? context.pop() : _home(context),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 22).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                    child: Column(
                      children: [
                        HaloIcon(
                          icon: Icons.lock_rounded,
                          innerColor: AppColors.ink,
                          foreground: AppColors.white,
                        ),
                        SizedBox(height: 26),
                        Text(
                          'Facilities staff only',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.21,
                          ),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: 260,
                          child: Text(
                            'This section is for admins who manage campus '
                            'repairs.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (user != null) SignedInCard(user: user),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Work in Facilities? Ask your coordinator for '
                          'access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      PrimaryPillButton(
                        label: 'Back to home',
                        onPressed: () => _home(context),
                      ),
                    ],
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

/// "aarav.shah@adit.ac.in · Signed in as Student" card.
class SignedInCard extends StatelessWidget {
  const SignedInCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final role = user.isAdmin ? 'Facilities admin' : 'Student';
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          UserAvatar(avatarId: user.avatar, name: user.displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Signed in as $role',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: DsPill(
              label: user.isAdmin ? 'Admin' : 'Student',
              background: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
