import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/utils/photo_picker.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/ds/ds_student.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/issue_enums.dart';
import '../bloc/issue_form_cubit.dart';
import '../widgets/student_issue_text.dart';

/// "New report" form (design screens 05 and 15).
class ReportIssuePage extends StatelessWidget {
  const ReportIssuePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<IssueFormCubit>(),
    child: const _ReportIssueView(),
  );
}

class _ReportIssueView extends StatefulWidget {
  const _ReportIssueView();

  @override
  State<_ReportIssueView> createState() => _ReportIssueViewState();
}

class _ReportIssueViewState extends State<_ReportIssueView> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  /// One tap opens the camera; a small link below picks from the gallery.
  Future<void> _takePhoto() async {
    await context.read<IssueFormCubit>().addPhoto(PhotoSource.camera);
  }

  Future<void> _pickFromGallery() async {
    await context.read<IssueFormCubit>().addPhoto(PhotoSource.gallery);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final cubit = context.read<IssueFormCubit>();
    cubit.submit(
      title: _title.text,
      description: _description.text,
      locationDetail: _location.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<IssueFormCubit, IssueFormState>(
      listener: (context, state) {
        if (state.status == IssueFormStatus.success && state.created != null) {
          // Straight to the new report, with a short confirmation.
          context.showSnack('Report sent to Facilities.');
          context.pushReplacement(Routes.issueDetails(state.created!.id));
        } else if (state.message != null) {
          // Connectivity/upload problems get the banner instead of a snack.
          if (state.submitProblem == null) {
            context.showSnack(state.message!, isError: true);
          }
          context.read<IssueFormCubit>().messageShown();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<IssueFormCubit, IssueFormState>(
            builder: (context, state) {
              final problem = state.submitProblem;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (problem != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: switch (problem) {
                        IssueSubmitProblem.offline => const DsAlertBanner(
                          title: "You're offline",
                          message:
                              'Your details stay here. Photos need a '
                              'connection.',
                        ),
                        IssueSubmitProblem.upload => const DsAlertBanner(
                          title: "Photos didn't upload",
                          message:
                              'Your details stay here. Retry, or remove a '
                              'photo and submit again.',
                        ),
                      },
                    ),
                  const DsTopBar(title: 'New report', backIcon: Icons.close),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: state.isSubmitting,
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.gutter,
                            6,
                            AppSizes.gutter,
                            16,
                          ),
                          children: [
                            _PhotoTiles(
                              state: state,
                              onAdd: _takePhoto,
                              onGallery: _pickFromGallery,
                              onRetry: _submit,
                            ),
                            const SizedBox(height: 10),
                            _PhotoGuidanceHint(
                              category: state.category,
                              hasPhoto: state.photos.isNotEmpty,
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel('Problem title'),
                            TextFormField(
                              controller: _title,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Fan not working in Room 204',
                                counterText: '',
                              ),
                              maxLength: AppConstants.titleMaxLength,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              validator: Validators.issueTitle,
                            ),
                            const SizedBox(height: 14),
                            _CategoryField(state: state),
                            const SizedBox(height: 14),
                            _WhereFields(state: state, location: _location),
                            const SizedBox(height: 14),
                            const _FieldLabel('Describe what you see'),
                            TextFormField(
                              controller: _description,
                              decoration: InputDecoration(
                                hintText: "e.g. The fan makes a loud noise and does not turn on",
                                counterText: '',
                                border: _roundBorder(),
                                enabledBorder: _roundBorder(),
                                focusedBorder: _roundBorder(
                                  const BorderSide(
                                    color: AppColors.ink,
                                    width: 1.5,
                                  ),
                                ),
                                errorBorder: _roundBorder(
                                  const BorderSide(color: AppColors.error),
                                ),
                                focusedErrorBorder: _roundBorder(
                                  const BorderSide(
                                    color: AppColors.error,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              minLines: 3,
                              maxLines: 6,
                              maxLength: AppConstants.descriptionMaxLength,
                              textCapitalization: TextCapitalization.sentences,
                              validator: Validators.issueDescription,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.gutter,
                      14,
                      AppSizes.gutter,
                      22,
                    ),
                    child: PrimaryPillButton(
                      label: problem == null ? 'Submit report' : 'Try again',
                      busy: state.isSubmitting,
                      onPressed: _submit,
                      trailing: PillBadge(
                        icon: problem == null
                            ? Icons.arrow_forward
                            : Icons.refresh,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _roundBorder([BorderSide side = BorderSide.none]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        borderSide: side,
      );
}

/// Tells the student whether this kind of problem needs a photo.
class _PhotoGuidanceHint extends StatelessWidget {
  const _PhotoGuidanceHint({required this.category, required this.hasPhoto});

  final IssueCategory? category;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    if (category == null) {
      return const InfoBanner(
        background: AppColors.surfaceRow,
        foreground: AppColors.textStrong,
        message:
            'Photos are optional. Choose a category to see if one is '
            'recommended.',
      );
    }
    final guidance = category.photoGuidance;
    final emphasise = guidance == PhotoGuidance.recommended && !hasPhoto;
    return InfoBanner(
      icon: guidance == PhotoGuidance.optional
          ? Icons.info_outline
          : Icons.photo_camera_outlined,
      background: emphasise ? AppColors.periwinkleLight : AppColors.surfaceRow,
      foreground: emphasise ? AppColors.textOnPeriwinkle : AppColors.textStrong,
      title: guidance.label,
      message: category.photoTip,
    );
  }
}

/// Photo tiles: picked photos (with remove ×) and the dashed "Add photo"
/// tile, two per row. After a connectivity/upload failure each photo shows
/// "Upload failed · Retry" (design screen 15).
class _PhotoTiles extends StatelessWidget {
  const _PhotoTiles({
    required this.state,
    required this.onAdd,
    required this.onGallery,
    required this.onRetry,
  });

  final IssueFormState state;
  final VoidCallback onAdd;
  final VoidCallback onGallery;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<IssueFormCubit>();
    final failed = state.submitProblem != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        final tiles = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, path) in state.photos.indexed)
              SizedBox(
                width: width,
                height: 120,
                child: _PhotoTile(
                  path: path,
                  index: i,
                  failed: failed,
                  onRemove: () => cubit.removePhoto(path),
                  onRetry: onRetry,
                ),
              ),
            if (state.canAddPhoto)
              SizedBox(
                width: width,
                height: 120,
                child: _AddPhotoTile(
                  count: state.photos.length,
                  dimmed: state.submitProblem == IssueSubmitProblem.offline,
                  onTap: onAdd,
                ),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tiles,
            if (state.canAddPhoto)
              TextButton.icon(
                onPressed: state.submitProblem == IssueSubmitProblem.offline
                    ? null
                    : onGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('or choose from gallery'),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.path,
    required this.index,
    required this.failed,
    required this.onRemove,
    required this.onRetry,
  });

  final String path;
  final int index;
  final bool failed;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (failed)
          Container(
            decoration: BoxDecoration(
              color: AppColors.statusReported,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.orange, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Upload failed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Semantics(
                    label: 'Retry uploading photo ${index + 1}',
                    excludeSemantics: true,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          )
        else
          Semantics(
            image: true,
            label: 'Photo ${index + 1}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => StripedPlaceholder(label: name),
              ),
            ),
          ),
        Positioned(
          top: 0,
          right: 0,
          child: Tooltip(
            message: 'Remove photo ${index + 1}',
            child: InkResponse(
              onTap: onRemove,
              radius: 24,
              child: SizedBox.square(
                dimension: 48,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.count,
    required this.onTap,
    this.dimmed = false,
  });

  final int count;
  final VoidCallback onTap;

  /// Greyed out while offline (photos need a connection).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take a photo, $count of ${AppConstants.maxPhotosPerIssue} added',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: dimmed ? AppColors.border : StudentShades.dashed,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: dimmed ? AppColors.border : AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: dimmed ? AppColors.textTertiary : AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take photo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dimmed
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.state});

  final IssueFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<IssueFormCubit>();
    return FormField<IssueCategory>(
      validator: (_) =>
          cubit.state.category == null ? 'Choose a category.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              'Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in IssueCategory.values)
                DsChip(
                  label: StudentIssueText.category(c),
                  selected: state.category == c,
                  dense: true,
                  onTap: () {
                    cubit.categoryChanged(c);
                    field.didChange(c);
                  },
                ),
            ],
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Text(
                field.errorText!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _WhereFields extends StatelessWidget {
  const _WhereFields({required this.state, required this.location});

  final IssueFormState state;
  final TextEditingController location;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<IssueFormCubit>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: state.buildingId,
            isExpanded: true,
            hint: const Text('Building', overflow: TextOverflow.ellipsis),
            borderRadius: BorderRadius.circular(20),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(18, 12, 8, 12),
            ),
            icon: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: AppColors.white,
              ),
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
            items: [
              for (final b in CampusBuildings.all)
                DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (b) => b == null ? null : cubit.buildingChanged(b),
            validator: (b) => b == null ? 'Choose a building.' : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: location,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Floor · Room',
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
            ),
            maxLength: AppConstants.locationMaxLength,
            validator: Validators.locationDetail,
          ),
        ),
      ],
    );
  }
}

/// Always-visible label above a form field. Hint text disappears once the
/// student types, so it can't be the only thing telling them what a box is.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
