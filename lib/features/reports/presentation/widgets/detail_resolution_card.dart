import 'package:flutter/material.dart';

import '../../../../core/widgets/ds/ds.dart';
import '../../domain/entities/issue.dart';
import 'issue_photo.dart';

/// Resolution proof card (design screen 09): the resolution photo (or a
/// striped placeholder) and the "Note from Facilities".
class DetailResolutionCard extends StatelessWidget {
  const DetailResolutionCard({
    super.key,
    required this.issue,
    this.showPhoto = true,
  });

  final Issue issue;

  /// The detail page hides the placeholder when there is no photo.
  final bool showPhoto;

  @override
  Widget build(BuildContext context) {
    final photos = issue.resolutionPhotoPaths;
    final note = issue.resolutionNote?.trim() ?? '';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceRow,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photos.isNotEmpty || showPhoto)
            Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  height: 130,
                  child: photos.isEmpty
                      ? const StripedPlaceholder(
                          radius: 0,
                          label: 'No resolution photo',
                        )
                      : PageView(
                          children: [
                            for (var i = 0; i < photos.length; i++)
                              Semantics(
                                image: true,
                                label:
                                    'Resolution photo ${i + 1} of '
                                    '${photos.length}',
                                child: IssuePhoto(photos[i]),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              photos.isNotEmpty || showPhoto ? 6 : 16,
              18,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note from Facilities',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.isEmpty ? 'No note was added.' : note,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
