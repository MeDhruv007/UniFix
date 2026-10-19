import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/photo_picker.dart';
import '../../../reports/domain/entities/issue.dart';
import '../../../reports/domain/entities/issue_enums.dart';
import '../../../reports/domain/repositories/issue_repository.dart';

enum StaffListStatus { initial, loading, loaded, failure }

enum AdminSubmitStatus { idle, submitting, success, failure }

/// What the current submit state refers to.
enum AdminAction { save, photo, resolve }

final class AdminIssueState extends Equatable {
  const AdminIssueState({
    this.issue,
    this.status,
    this.priority,
    this.assigneeId,
    this.staffStatus = StaffListStatus.initial,
    this.staff = const [],
    this.submit = AdminSubmitStatus.idle,
    this.action,
    this.message,
    this.photos = const [],
  });

  /// What the issue looks like on the server (as far as we know). Updated
  /// after each successful change so a retry only re-sends failed ones.
  final Issue? issue;

  /// Draft selections in the update sheet.
  final IssueStatus? status;
  final IssuePriority? priority;
  final String? assigneeId;

  final StaffListStatus staffStatus;
  final List<StaffMember> staff;

  final AdminSubmitStatus submit;
  final AdminAction? action;

  /// User-safe outcome text (success summary or which change failed).
  final String? message;

  /// Local resolution photos picked on the "Mark resolved" screen, not yet
  /// uploaded.
  final List<String> photos;

  bool get isSubmitting => submit == AdminSubmitStatus.submitting;

  bool get statusChanged => issue != null && status != issue!.status;
  bool get priorityChanged => issue != null && priority != issue!.priority;
  bool get assigneeChanged => issue != null && assigneeId != issue!.assignedTo;
  bool get hasChanges => statusChanged || priorityChanged || assigneeChanged;

  AdminIssueState copyWith({
    Issue? issue,
    IssueStatus? status,
    IssuePriority? priority,
    String? Function()? assigneeId,
    StaffListStatus? staffStatus,
    List<StaffMember>? staff,
    AdminSubmitStatus? submit,
    AdminAction? Function()? action,
    String? Function()? message,
    List<String>? photos,
  }) => AdminIssueState(
    issue: issue ?? this.issue,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
    staffStatus: staffStatus ?? this.staffStatus,
    staff: staff ?? this.staff,
    submit: submit ?? this.submit,
    action: action != null ? action() : this.action,
    message: message != null ? message() : this.message,
    photos: photos ?? this.photos,
  );

  @override
  List<Object?> get props => [
    issue,
    status,
    priority,
    assigneeId,
    staffStatus,
    staff,
    submit,
    action,
    message,
    photos,
  ];
}

/// Admin actions on one issue:
/// - the "Update issue" sheet: [init], draft selections, batched [save];
/// - the "Mark resolved" screen: [addPhoto]/[removePhoto] and [resolve].
///
/// The API server is the real authority; checks here only give faster,
/// clearer feedback.
class AdminIssueCubit extends Cubit<AdminIssueState> {
  AdminIssueCubit({required this._repository, required this._photoPicker})
    : super(const AdminIssueState());

  final IssueRepository _repository;
  final PhotoPicker _photoPicker;

  static const int maxNoteLength = AppConstants.noteMaxLength;

  // ---------- update sheet ----------

  /// Seeds the drafts from [issue] and loads the staff list.
  Future<void> init(Issue issue) async {
    emit(
      AdminIssueState(
        issue: issue,
        status: issue.status,
        priority: issue.priority,
        assigneeId: issue.assignedTo,
      ),
    );
    await loadStaff();
  }

  Future<void> loadStaff() async {
    emit(state.copyWith(staffStatus: StaffListStatus.loading));
    try {
      final staff = await _repository.listStaff();
      if (isClosed) return;
      emit(state.copyWith(staffStatus: StaffListStatus.loaded, staff: staff));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(staffStatus: StaffListStatus.failure));
    }
  }

  /// Only the current status or a valid next status may be selected;
  /// resolving goes through the "Mark resolved" screen instead.
  void selectStatus(IssueStatus status) {
    final current = state.issue?.status;
    if (current == null || state.isSubmitting) return;
    if (status == IssueStatus.resolved) return;
    if (status != current && !current.canTransitionTo(status)) return;
    emit(state.copyWith(status: status, message: () => null));
  }

  void selectPriority(IssuePriority priority) {
    if (state.isSubmitting) return;
    emit(state.copyWith(priority: priority, message: () => null));
  }

  /// Null = unassigned.
  void selectAssignee(String? staffId) {
    if (state.isSubmitting) return;
    emit(state.copyWith(assigneeId: () => staffId, message: () => null));
  }

  /// Applies only what changed, in order: status (with [note]), priority,
  /// assignee. Each change is attempted even if an earlier one fails; the
  /// resulting message names the changes that failed.
  Future<void> save({String? note}) async {
    final issue = state.issue;
    if (issue == null || state.isSubmitting) return;
    if (!state.hasChanges) {
      emit(
        state.copyWith(
          submit: AdminSubmitStatus.failure,
          action: () => AdminAction.save,
          message: () => 'Nothing to save yet.',
        ),
      );
      return;
    }
    final cleanNote = note?.trim();
    if (cleanNote != null && cleanNote.length > maxNoteLength) {
      emit(
        state.copyWith(
          submit: AdminSubmitStatus.failure,
          action: () => AdminAction.save,
          message: () => 'Keep the note under $maxNoteLength characters.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        submit: AdminSubmitStatus.submitting,
        action: () => AdminAction.save,
        message: () => null,
      ),
    );

    var current = issue;
    final saved = <String>[];
    final failed = <String>[];

    if (state.statusChanged) {
      final to = state.status!;
      try {
        await _repository.updateStatus(
          issue.id,
          from: current.status,
          to: to,
          note: (cleanNote?.isEmpty ?? true) ? null : cleanNote,
        );
        current = _with(current, status: to);
        saved.add('status');
      } catch (e, st) {
        failed.add('Status: ${mapException(e, st).message}');
      }
    }
    if (state.priorityChanged) {
      final to = state.priority!;
      try {
        await _repository.updatePriority(
          issue.id,
          from: current.priority,
          to: to,
        );
        current = _with(current, priority: to);
        saved.add('priority');
      } catch (e, st) {
        failed.add('Priority: ${mapException(e, st).message}');
      }
    }
    if (state.assigneeChanged) {
      final to = state.assigneeId;
      try {
        await _repository.assignTo(issue.id, to);
        current = _with(current, assignee: () => to);
        saved.add('assignee');
      } catch (e, st) {
        failed.add('Assignment: ${mapException(e, st).message}');
      }
    }
    if (isClosed) return;

    if (failed.isEmpty) {
      emit(
        state.copyWith(
          issue: current,
          submit: AdminSubmitStatus.success,
          message: () => 'Changes saved.',
        ),
      );
    } else {
      final savedText = saved.isEmpty
          ? 'Nothing was saved.'
          : 'Saved ${saved.join(' and ')}.';
      emit(
        state.copyWith(
          issue: current,
          submit: AdminSubmitStatus.failure,
          message: () =>
              'Could not save every change. $savedText\n'
              '${failed.join('\n')}',
        ),
      );
    }
  }

  // ---------- mark resolved ----------

  /// Picks one photo into [AdminIssueState.photos]. [existingCount] is how
  /// many resolution photos the issue already has.
  Future<void> addPhoto(PhotoSource source, {int existingCount = 0}) async {
    if (state.isSubmitting) return;
    if (existingCount + state.photos.length >= AppConstants.maxPhotosPerIssue) {
      _fail(
        AdminAction.photo,
        'You can attach up to ${AppConstants.maxPhotosPerIssue} photos.',
      );
      return;
    }
    final String? path;
    try {
      path = await _photoPicker.pick(source);
    } catch (e, st) {
      _fail(AdminAction.photo, mapException(e, st).message);
      return;
    }
    if (path == null || isClosed) return;
    emit(
      state.copyWith(
        photos: [...state.photos, path],
        submit: AdminSubmitStatus.idle,
        action: () => null,
        message: () => null,
      ),
    );
  }

  void removePhoto(int index) {
    if (state.isSubmitting || index < 0 || index >= state.photos.length) {
      return;
    }
    emit(state.copyWith(photos: [...state.photos]..removeAt(index)));
  }

  /// Uploads the picked photos, then moves [issue] to resolved with [note].
  Future<void> resolve(Issue issue, String note) async {
    if (state.isSubmitting) return;
    final cleaned = note.trim();
    if (!issue.status.canTransitionTo(IssueStatus.resolved)) {
      _fail(
        AdminAction.resolve,
        'A report cannot move from ${issue.status.label} to Resolved.',
      );
      return;
    }
    if (cleaned.isEmpty) {
      _fail(AdminAction.resolve, 'Describe what was done before resolving.');
      return;
    }
    if (cleaned.length > maxNoteLength) {
      _fail(
        AdminAction.resolve,
        'Keep the note under $maxNoteLength characters.',
      );
      return;
    }
    emit(
      state.copyWith(
        submit: AdminSubmitStatus.submitting,
        action: () => AdminAction.resolve,
        message: () => null,
      ),
    );
    if (state.photos.isNotEmpty) {
      try {
        await _repository.addResolutionPhotos(
          issue.id,
          state.photos,
          existingCount: issue.resolutionPhotoPaths.length,
        );
      } catch (e, st) {
        _fail(
          AdminAction.resolve,
          'Photos could not be uploaded, so the issue was not resolved. '
          '${mapException(e, st).message}',
        );
        return;
      }
      if (isClosed) return;
      // Uploaded: they now belong to the issue; don't send them again.
      emit(state.copyWith(photos: const []));
    }
    try {
      await _repository.updateStatus(
        issue.id,
        from: issue.status,
        to: IssueStatus.resolved,
        note: cleaned,
      );
    } catch (e, st) {
      _fail(AdminAction.resolve, mapException(e, st).message);
      return;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        submit: AdminSubmitStatus.success,
        action: () => AdminAction.resolve,
        message: () => 'Issue marked as resolved.',
      ),
    );
  }

  void messageShown() {
    if (state.message == null) return;
    emit(state.copyWith(message: () => null));
  }

  void _fail(AdminAction action, String message) {
    if (isClosed) return;
    emit(
      state.copyWith(
        submit: AdminSubmitStatus.failure,
        action: () => action,
        message: () => message,
      ),
    );
  }

  static Issue _with(
    Issue i, {
    IssueStatus? status,
    IssuePriority? priority,
    String? Function()? assignee,
  }) => Issue(
    id: i.id,
    campusId: i.campusId,
    title: i.title,
    description: i.description,
    category: i.category,
    buildingId: i.buildingId,
    locationDetail: i.locationDetail,
    reporterId: i.reporterId,
    status: status ?? i.status,
    priority: priority ?? i.priority,
    photoPaths: i.photoPaths,
    reporterDisplayName: i.reporterDisplayName,
    assignedTo: assignee != null ? assignee() : i.assignedTo,
    resolutionNote: i.resolutionNote,
    resolutionPhotoPaths: i.resolutionPhotoPaths,
    createdAt: i.createdAt,
    updatedAt: i.updatedAt,
    resolvedAt: i.resolvedAt,
    reopenCount: i.reopenCount,
    number: i.number,
    code: i.code,
    assignedToName: i.assignedToName,
  );
}
