import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'issue_photo.dart';

/// Pops the route, or goes to the user's landing tab when opened directly
/// (deep link / web refresh) with nothing to pop.
void popOrGoHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final isAdmin = context.read<AuthBloc>().state.isAdmin;
  context.go(isAdmin ? Routes.admin : Routes.home);
}

/// Design screen 07's photo header: inset 10px, radius 40, swipeable
/// photos with page dots and a white circle back button on top. Shows a
/// striped "No photo" placeholder when the report has no photos.
class DetailPhotoHeader extends StatefulWidget {
  const DetailPhotoHeader({
    super.key,
    required this.photoPaths,
    this.height = 280,
  });

  final List<String> photoPaths;
  final double height;

  @override
  State<DetailPhotoHeader> createState() => _DetailPhotoHeaderState();
}

class _DetailPhotoHeaderState extends State<DetailPhotoHeader> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final photos = widget.photoPaths;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: SizedBox(
        height: widget.height + (top > 40 ? top - 40 : 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photos.isEmpty)
                const StripedPlaceholder(radius: 0, label: 'No photo')
              else
                PageView.builder(
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => Semantics(
                    image: true,
                    label: 'Issue photo ${i + 1} of ${photos.length}',
                    child: IssuePhoto(photos[i]),
                  ),
                ),
              Positioned(
                top: (top - 6).clamp(8, 60) + 8,
                left: 14,
                child: CircleIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  filled: true,
                  onPressed: () => popOrGoHome(context),
                ),
              ),
              if (photos.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppColors.ink
                                  : AppColors.ink.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
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
