import 'package:flutter/material.dart';

import '../../../../core/widgets/unifix_loader.dart';

/// Shown while the session is being restored. The app-level launch overlay
/// (see `app.dart`) draws the same loader on top and fades it out.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const UniFixLoader();
}
