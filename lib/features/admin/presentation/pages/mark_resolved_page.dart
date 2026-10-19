import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/photo_picker.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../../reports/domain/entities/issue.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/presentation/bloc/issue_details_cubit.dart';
import '../../../reports/presentation/widgets/issue_photo.dart';
import '../bloc/admin_issue_cubit.dart';
import '../widgets/admin_format.dart';

/// Design screen 13: resolution note, proof-of-repair photos, then
/// "Mark as resolved". Pops back to the details page on success.
class MarkResolvedPage extends StatelessWidget {
  const MarkResolvedPage({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<IssueDetailsCubit>(param1: issueId)..start(),
        ),
        BlocProvider(create: (_) => getIt<AdminIssueCubit>()),
      ],
      child: const MarkResolvedView(),
    );
  }
}

/// Expects an [IssueDetailsCubit] (the live issue) and an
/// [AdminIssueCubit] above it.
class MarkResolvedView extends StatelessWidget {
  const MarkResolvedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DsTopBar(title: 'Resolve issue'),
      body: BlocBuilder<IssueDetailsCubit, IssueDetailsState>(
        builder: (context, state) => switch (state.status) {
          IssueDetailsStatus.loading => const LoadingView(),
          IssueDetailsStatus.notFound => EmptyView(
            icon: Icons.search_off,
            message: state.message ?? 'Report not found.',
          ),
          IssueDetailsStatus.failure when state.issue == null => ErrorView(
            message: state.message ?? 'Could not load this report.',
            onRetry: context.read<IssueDetailsCubit>().start,
          ),
          _ => _ResolveForm(issue: state.issue!),
        },
      ),
    );
  }
}

class _ResolveForm extends StatefulWidget {
  const _ResolveForm({required this.issue});

  final Issue issue;

  @override
  State<_ResolveForm> createState() => _ResolveFormState();
}

class _ResolveFormState extends State<_ResolveForm> {
  final _note = TextEditingController();
  bool _showNoteError = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_note.text.trim().isEmpty) {
      setState(() => _showNoteError = true);
      return;
    }
    context.read<AdminIssueCubit>().resolve(widget.issue, _note.text);
  }

  /// The tile opens the camera; a small link below picks from the gallery.
  Future<void> _addPhoto(PhotoSource source) =>
      context.read<AdminIssueCubit>().addPhoto(
        source,
        existingCount: widget.issue.resolutionPhotoPaths.length,
      );

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final canResolve = issue.status.canTransitionTo(IssueStatus.resolved);
    return BlocConsumer<AdminIssueCubit, AdminIssueState>(
      listenWhen: (prev, curr) =>
          curr.message != null &&
          (prev.message != curr.message || prev.submit != curr.submit),
      listener: (context, state) {
        if (state.submit == AdminSubmitStatus.success &&
            state.action == AdminAction.resolve) {
          context.showSnack(state.message!);
          Navigator.of(context).maybePop();
          return;
        }
        if (state.submit == AdminSubmitStatus.failure) {
          context.showSnack(state.message!, isError: true);
          context.read<AdminIssueCubit>().messageShown();
        }
      },
      builder: (context, state) {
        final busy = state.isSubmitting;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.gutter,
                  4,
                  AppSizes.gutter,
                  16,
                ),
                children: [
                  _SummaryCard(issue: issue),
                  if (!canResolve) ...[
                    const SizedBox(height: 14),
                    InfoBanner(
                      background: AppColors.statusReported,
                      foreground: AppColors.ink,
                      message: issue.status == IssueStatus.resolved
                          ? 'This issue is already resolved.'
                          : 'Start work on this issue before resolving it '
                                '(it is ${issue.status.label.toLowerCase()}).',
                    ),
                  ],
                  const SizedBox(height: 14),
                  const _FieldLabel('What was done'),
                  _NoteField(
                    controller: _note,
                    enabled: canResolve && !busy,
                    showError: _showNoteError,
                    onChanged: () {
                      if (_showNoteError) {
                        setState(() => _showNoteError = false);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Proof of repair'),
                  _PhotoGrid(
                    existing: issue.resolutionPhotoPaths,
                    pending: state.photos,
                    enabled: canResolve && !busy,
                    onAdd: () => _addPhoto(PhotoSource.camera),
                    onGallery: () => _addPhoto(PhotoSource.gallery),
                    onRemove: context.read<AdminIssueCubit>().removePhoto,
                  ),
                  const SizedBox(height: 14),
                  const _ConfirmInfo(),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.gutter,
                  0,
                  AppSizes.gutter,
                  22,
                ),
                child: PrimaryPillButton(
                  label: 'Mark as resolved',
                  busy: busy,
                  trailing: const PillBadge(icon: Icons.check),
                  onPressed: canResolve ? _submit : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final since = issue.updatedAt ?? issue.createdAt;
    final meta = [
      issue.displayCode,
      if (issue.locationDetail.trim().isNotEmpty) issue.locationDetail.trim(),
      '${issue.status.label.toLowerCase()} ${AdminFormat.age(since)}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.periwinkleLight,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          CodeAvatar(
            code: issue.category.code,
            background: AppColors.white,
            foreground: AppColors.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textOnPeriwinkle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.enabled,
    required this.showError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool showError;
  final VoidCallback onChanged;

  static const _max = AdminIssueCubit.maxNoteLength;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide(color: c, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: 4,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(_max)],
          onChanged: (_) => onChanged(),
          style: const TextStyle(fontSize: 13, height: 1.5),
          decoration: InputDecoration(
            filled: false,
            hintText: 'Describe the repair (required)',
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            border: border(AppColors.ink),
            enabledBorder: border(showError ? AppColors.error : AppColors.ink),
            focusedBorder: border(showError ? AppColors.error : AppColors.ink),
            disabledBorder: border(AppColors.border),
            errorText: showError
                ? 'Describe what was done before resolving.'
                : null,
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Text(
              '${value.text.characters.length} / $_max',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.existing,
    required this.pending,
    required this.enabled,
    required this.onAdd,
    required this.onGallery,
    required this.onRemove,
  });

  final List<String> existing;
  final List<String> pending;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final total = existing.length + pending.length;
    final tiles = <Widget>[
      for (final p in existing)
        _Tile(semanticLabel: 'Uploaded resolution photo', child: IssuePhoto(p)),
      for (var i = 0; i < pending.length; i++)
        _Tile(
          semanticLabel: 'New photo ${i + 1}',
          onRemove: enabled ? () => onRemove(i) : null,
          child: Image.file(
            File(pending[i]),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const StripedPlaceholder(radius: 0, label: 'photo'),
          ),
        ),
      if (total < AppConstants.maxPhotosPerIssue)
        _AddTile(onTap: enabled ? onAdd : null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 150 / 110,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        ),
        if (total < AppConstants.maxPhotosPerIssue)
          TextButton.icon(
            onPressed: enabled ? onGallery : null,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('or choose from gallery'),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.child,
    required this.semanticLabel,
    this.onRemove,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: child,
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: CircleIconButton(
              icon: Icons.close,
              tooltip: 'Remove photo',
              filled: true,
              onPressed: onRemove,
            ),
          ),
      ],
    ),
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take a photo',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: onTap == null ? AppColors.border : AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Take photo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
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

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      const Radius.circular(AppRadii.card),
    );
    final paint = Paint()
      ..color = AppColors.textTertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

/// Non-interactive: reporters always get the feedback prompt once an
/// issue is resolved.
class _ConfirmInfo extends StatelessWidget {
  const _ConfirmInfo();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, size: 22, color: AppColors.ink),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'The reporter will be asked to confirm the fix',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
