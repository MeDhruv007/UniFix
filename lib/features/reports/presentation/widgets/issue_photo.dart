import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/issue_repository.dart';

/// Displays a photo stored by the API at [path] (an issue `photoPaths`
/// entry). Photos are protected, so the request carries the session token.
class IssuePhoto extends StatelessWidget {
  const IssuePhoto(this.path, {super.key, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final ref = context.read<IssueRepository>().photo(path);
    return CachedNetworkImage(
      imageUrl: ref.url,
      httpHeaders: ref.headers,
      // Cache by path, not by URL+token, so a new session reuses the cache.
      cacheKey: path,
      fit: fit,
      placeholder: (_, _) => const _PhotoBox(icon: Icons.image_outlined),
      errorWidget: (_, _, _) => const _PhotoBox(
        icon: Icons.broken_image_outlined,
        semanticLabel: 'Photo could not be loaded',
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.icon, this.semanticLabel});

  final IconData icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.periwinkleLight,
    child: Center(
      child: Icon(
        icon,
        color: AppColors.textOnPeriwinkle,
        semanticLabel: semanticLabel,
      ),
    ),
  );
}
