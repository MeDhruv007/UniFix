import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/unifix_loader.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/reports/domain/repositories/issue_repository.dart';
import 'injection_container.dart';

class UniFixApp extends StatefulWidget {
  const UniFixApp({super.key});

  @override
  State<UniFixApp> createState() => _UniFixAppState();
}

class _UniFixAppState extends State<UniFixApp> {
  late final AuthBloc _authBloc = getIt<AuthBloc>()
    ..add(const AuthSubscriptionRequested());
  late final GoRouter _router = createRouter(_authBloc);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<IssueRepository>.value(
      value: getIt<IssueRepository>(),
      child: BlocProvider.value(
        value: _authBloc,
        child: MaterialApp.router(
          title: AppConstants.appName,
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) =>
              _LaunchGate(authBloc: _authBloc, child: child!),
        ),
      ),
    );
  }
}

/// Keeps the animated loader over the app until the session is known and
/// [UniFixLoader.minimumShow] has passed, then cross-fades (250 ms) to the
/// first screen.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate({required this.authBloc, required this.child});

  final AuthBloc authBloc;
  final Widget child;

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool _minTimePassed = false;
  bool _fading = false;
  bool _gone = false;
  StreamSubscription<AuthState>? _auth;

  @override
  void initState() {
    super.initState();
    Future.delayed(UniFixLoader.minimumShow, () {
      if (!mounted) return;
      _minTimePassed = true;
      _maybeFade();
    });
    _auth = widget.authBloc.stream.listen((_) => _maybeFade());
  }

  void _maybeFade() {
    if (_fading || !_minTimePassed) return;
    if (widget.authBloc.state.session == SessionStatus.unknown) return;
    _auth?.cancel();
    setState(() => _fading = true);
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  /// Once the loader is gone the system bars go back to white (otherwise
  /// they keep the loader's orange).
  static const _appBars = SystemUiOverlayStyle(
    statusBarColor: AppColors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: AppColors.white,
  );

  @override
  Widget build(BuildContext context) {
    final app = AnnotatedRegion<SystemUiOverlayStyle>(
      value: _appBars,
      child: widget.child,
    );
    if (_gone) return app;
    return Stack(
      children: [
        app,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _fading,
            child: AnimatedOpacity(
              opacity: _fading ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              onEnd: () => setState(() => _gone = true),
              child: const UniFixLoader(),
            ),
          ),
        ),
      ],
    );
  }
}
