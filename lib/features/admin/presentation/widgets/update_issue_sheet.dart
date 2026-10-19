import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/domain/entities/issue.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/domain/repositories/issue_repository.dart';
import '../bloc/admin_issue_cubit.dart';
import 'admin_format.dart';

/// Which section the sheet scrolls to when it opens.
enum UpdateSheetFocus { none, assignment }

/// Opens design screen 12 for [issue]. Shows a confirmation snackbar after
/// a successful save.
Future<void> showUpdateIssueSheet(
  BuildContext context,
  Issue issue, {
  UpdateSheetFocus focus = UpdateSheetFocus.none,
}) async {
  final adminName = context.read<AuthBloc>().state.user?.displayName;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The sheet draws its own handle (the theme would add a second one).
    showDragHandle: false,
    backgroundColor: AppColors.white,
    barrierColor: const Color(0x731E2232),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
    ),
    builder: (_) => BlocProvider(
      create: (_) => getIt<AdminIssueCubit>()..init(issue),
      child: UpdateIssueSheet(
        focus: focus,
        adminName: adminName,
        onResolve: () => context.push(Routes.adminResolve(issue.id)),
      ),
    ),
  );
  if (saved == true && context.mounted) {
    context.showSnack(
      adminName == null
          ? 'Changes saved to the history.'
          : 'Changes saved · added to history as $adminName.',
    );
  }
}

/// Body of the "Update issue" sheet. Expects an [AdminIssueCubit] that was
/// [AdminIssueCubit.init]ialised with the issue. Pops `true` after saving.
class UpdateIssueSheet extends StatefulWidget {
  const UpdateIssueSheet({
    super.key,
    this.focus = UpdateSheetFocus.none,
    this.adminName,
    this.onResolve,
  });

  final UpdateSheetFocus focus;
  final String? adminName;

  /// Opens the "Mark resolved" screen (called after the sheet closes).
  final VoidCallback? onResolve;

  @override
  State<UpdateIssueSheet> createState() => _UpdateIssueSheetState();
}

class _UpdateIssueSheetState extends State<UpdateIssueSheet> {
  final _note = TextEditingController();
  final _assignKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus == UpdateSheetFocus.assignment) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAssign());
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _scrollToAssign() {
    final ctx = _assignKey.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.05,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _resolve() {
    Navigator.of(context).pop();
    widget.onResolve?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return BlocConsumer<AdminIssueCubit, AdminIssueState>(
      listenWhen: (prev, curr) =>
          prev.submit != curr.submit ||
          (prev.staffStatus != curr.staffStatus &&
              curr.staffStatus == StaffListStatus.loaded),
      listener: (context, state) {
        if (state.submit == AdminSubmitStatus.success) {
          Navigator.of(context).pop(true);
        } else if (state.staffStatus == StaffListStatus.loaded &&
            widget.focus == UpdateSheetFocus.assignment) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToAssign(),
          );
        }
      },
      builder: (context, state) {
        final issue = state.issue;
        if (issue == null) {
          return const SizedBox(height: 240, child: LoadingView());
        }
        final cubit = context.read<AdminIssueCubit>();
        final busy = state.isSubmitting;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              10,
              AppSizes.gutter,
              22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: const Text(
                          'Update issue',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _IssueHeader(issue: issue),
                const SizedBox(height: 16),
                const _Label('Status'),
                _StatusSegments(
                  current: issue.status,
                  selected: state.status ?? issue.status,
                  enabled: !busy,
                  onSelect: cubit.selectStatus,
                ),
                if (issue.status.canTransitionTo(IssueStatus.resolved))
                  _ResolveHint(onResolve: busy ? null : _resolve),
                const SizedBox(height: 16),
                const _Label('Priority'),
                _PrioritySegments(
                  selected: state.priority ?? issue.priority,
                  onSelect: busy ? null : cubit.selectPriority,
                ),
                const SizedBox(height: 16),
                _Label('Assign to', key: _assignKey),
                _AssigneeList(
                  state: state,
                  enabled: !busy,
                  myUid: context.select((AuthBloc b) => b.state.user?.uid),
                  onSelect: cubit.selectAssignee,
                  onRetry: cubit.loadStaff,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  enabled: !busy && state.statusChanged,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      AdminIssueCubit.maxNoteLength,
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: state.statusChanged
                        ? 'Note for the history (optional)'
                        : 'Change the status to add a note',
                  ),
                ),
                if (state.submit == AdminSubmitStatus.failure &&
                    state.message != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(message: state.message!),
                ],
                const SizedBox(height: 16),
                PrimaryPillButton(
                  label: 'Save changes',
                  busy: busy,
                  onPressed: state.hasChanges
                      ? () => cubit.save(
                          note: state.statusChanged ? _note.text : null,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.adminName == null
                      ? 'Changes are added to the issue history'
                      : 'Added to history as ${widget.adminName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _IssueHeader extends StatelessWidget {
  const _IssueHeader({required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final swatch = issue.category.swatch;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: swatch.background,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: swatch.foreground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${issue.displayCode} · ${issue.category.label.toUpperCase()}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              issue.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AdminFormat.location(issue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-way status control. Only the current status and valid next ones
/// (except Resolved, which has its own screen) can be selected.
class _StatusSegments extends StatelessWidget {
  const _StatusSegments({
    required this.current,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final IssueStatus current;
  final IssueStatus selected;
  final bool enabled;
  final ValueChanged<IssueStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    final options =
        current == IssueStatus.resolved || current == IssueStatus.reopened
        ? const [
            IssueStatus.inProgress,
            IssueStatus.resolved,
            IssueStatus.reopened,
          ]
        : const [
            IssueStatus.reported,
            IssueStatus.inProgress,
            IssueStatus.resolved,
          ];
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          for (final s in options)
            Expanded(
              child: _Segment(
                label: s.label,
                selected: s == selected,
                enabled:
                    enabled &&
                    s != IssueStatus.resolved &&
                    (s == current || current.canTransitionTo(s)),
                onTap: () => onSelect(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled || selected,
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled && !selected ? onTap : null,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.white
                    : enabled
                    ? AppColors.textStrong
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResolveHint extends StatelessWidget {
  const _ResolveHint({required this.onResolve});

  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 6),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Resolving needs a note and proof of repair.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: onResolve,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Mark resolved'),
        ),
      ],
    ),
  );
}

class _PrioritySegments extends StatelessWidget {
  const _PrioritySegments({required this.selected, required this.onSelect});

  final IssuePriority selected;
  final ValueChanged<IssuePriority>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in IssuePriority.values) ...[
          if (p != IssuePriority.values.first) const SizedBox(width: 6),
          Expanded(child: _priorityButton(p)),
        ],
      ],
    );
  }

  Widget _priorityButton(IssuePriority p) {
    final isSelected = p == selected;
    final isUrgent = p == IssuePriority.urgent;
    final Color background = isSelected
        ? (isUrgent ? AppColors.orange : AppColors.periwinkle)
        : (isUrgent ? AppColors.statusReported : AppColors.white);
    final BorderSide side = isSelected
        ? const BorderSide(color: AppColors.ink, width: 2)
        : isUrgent
        ? BorderSide.none
        : const BorderSide(color: AppColors.border);
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: background,
        shape: StadiumBorder(side: side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect == null ? null : () => onSelect!(p),
          child: SizedBox(
            height: 48,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssigneeList extends StatelessWidget {
  const _AssigneeList({
    required this.state,
    required this.enabled,
    required this.myUid,
    required this.onSelect,
    required this.onRetry,
  });

  final AdminIssueState state;
  final bool enabled;
  final String? myUid;
  final ValueChanged<String?> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _AssigneeRow(
        name: 'Unassigned',
        avatar: const Icon(Icons.person_off_outlined, size: 20),
        selected: state.assigneeId == null,
        onTap: enabled ? () => onSelect(null) : null,
      ),
    ];
    switch (state.staffStatus) {
      case StaffListStatus.initial || StaffListStatus.loading:
        rows.add(
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      case StaffListStatus.failure:
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Could not load staff.',
                    style: TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        );
      case StaffListStatus.loaded:
        final staff = state.staff;
        // Keep the current assignee visible even if not in the list.
        final current = state.issue?.assignedTo;
        final missing = current != null && staff.every((s) => s.id != current);
        for (final s in [
          ...staff,
          if (missing)
            StaffMember(
              id: current,
              displayName: state.issue?.assignedToName ?? 'Current assignee',
            ),
        ]) {
          final selected = state.assigneeId == s.id;
          rows.add(
            _AssigneeRow(
              name: s.id == myUid ? '${s.displayName} (you)' : s.displayName,
              avatar: Text(
                CodeAvatar.initialsOf(s.displayName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.white : AppColors.ink,
                ),
              ),
              selected: selected,
              onTap: enabled ? () => onSelect(s.id) : null,
            ),
          );
        }
        if (staff.isEmpty && !missing) {
          rows.add(
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Text(
                'No staff accounts yet.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          );
        }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          rows[i],
        ],
      ],
    );
  }
}

class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({
    required this.name,
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Widget avatar;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.ink
                          : AppColors.periwinkleLight,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: selected ? AppColors.white : AppColors.ink,
                      ),
                      child: avatar,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: AppColors.ink, width: 7)
                          : Border.all(
                              color: AppColors.textTertiary,
                              width: 1.5,
                            ),
                    ),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.statusReopened,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
            ),
          ),
        ],
      ),
    ),
  );
}
