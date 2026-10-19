import 'dart:async';

import '../../../../core/config/api_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import '../../domain/entities/issue_update.dart';
import '../../domain/repositories/issue_repository.dart';
import '../datasources/issue_api_data_source.dart';

/// REST implementation. The API has no push channel, so "watch" streams
/// poll every [ApiConfig.pollInterval] and re-fetch immediately after any
/// write made through this repository.
class IssueRepositoryImpl implements IssueRepository {
  IssueRepositoryImpl({
    required this._api,
    required this._client,
    this._pollInterval = ApiConfig.pollInterval,
  });

  final IssueApiDataSource _api;
  final ApiClient _client;
  final Duration _pollInterval;

  /// Signals that server data changed because of a local write.
  final _changed = StreamController<void>.broadcast();

  static const int maxNoteLength = AppConstants.noteMaxLength;

  @override
  Future<Issue> createIssue(NewIssueInput input) async {
    if (input.localPhotoPaths.length > AppConstants.maxPhotosPerIssue) {
      throw const ValidationFailure(
        'You can attach up to ${AppConstants.maxPhotosPerIssue} photos.',
      );
    }
    return _write(() => _api.create(input));
  }

  @override
  Stream<List<Issue>> watchIssues({
    IssueFilter filter = const IssueFilter(),
    int limit = AppConstants.feedPageSize,
  }) => _poll(() async => (await _api.list(filter, limit: limit)).items);

  @override
  Stream<Issue> watchIssue(String issueId) => _poll(() => _api.get(issueId));

  @override
  Stream<List<IssueUpdate>> watchUpdates(String issueId) =>
      _poll(() => _api.updates(issueId));

  @override
  PhotoRef photo(String photoPath) =>
      (url: ApiConfig.photoUrl(photoPath), headers: _client.authHeaders);

  // ---------- admin operations ----------

  @override
  Future<void> updateStatus(
    String issueId, {
    required IssueStatus from,
    required IssueStatus to,
    String? note,
  }) async {
    if (!from.canTransitionTo(to)) {
      throw ValidationFailure(
        'A report cannot move from ${from.label} to ${to.label}.',
      );
    }
    final cleaned = _cleanNote(note);
    if (to == IssueStatus.resolved && cleaned == null) {
      throw const ValidationFailure('Add a resolution note before resolving.');
    }
    await _write(
      () => _api.updateStatus(issueId, from: from, to: to, note: cleaned),
    );
  }

  @override
  Future<void> updatePriority(
    String issueId, {
    required IssuePriority from,
    required IssuePriority to,
  }) async {
    if (from == to) return;
    await _write(() => _api.updatePriority(issueId, from: from, to: to));
  }

  @override
  Future<void> assignToMe(String issueId) =>
      _write(() => _api.assignToMe(issueId));

  @override
  Future<void> addResolutionPhotos(
    String issueId,
    List<String> localPaths, {
    int existingCount = 0,
  }) async {
    if (localPaths.isEmpty) return;
    if (existingCount + localPaths.length > AppConstants.maxPhotosPerIssue) {
      throw const ValidationFailure(
        'You can attach up to ${AppConstants.maxPhotosPerIssue} '
        'resolution photos.',
      );
    }
    await _write(() => _api.addResolutionPhotos(issueId, localPaths));
  }

  /// The dashboard asks for each count in parallel; they share one request.
  /// Concurrent callers (e.g. one per dashboard tile) share one request.
  final Map<bool, Future<IssueStats>> _statsInFlight = {};

  @override
  Future<int> countIssues({IssueStatus? status}) async {
    final s = await stats();
    return status == null ? s.total : s.countFor(status);
  }

  @override
  Future<IssueStats> stats({bool mine = false}) async {
    try {
      return await _statsInFlight.putIfAbsent(
        mine,
        () =>
            _api.stats(mine: mine)
            // Block body: returning the removed future would make
            // whenComplete wait on itself.
            .whenComplete(() {
              _statsInFlight.remove(mine);
            }),
      );
    } catch (e, st) {
      throw mapException(e, st);
    }
  }

  @override
  Stream<IssueStats> watchStats({bool mine = false}) =>
      _poll(() => _api.stats(mine: mine));

  @override
  Future<List<StaffMember>> listStaff() async {
    try {
      return await _api.staff();
    } catch (e, st) {
      throw mapException(e, st);
    }
  }

  @override
  Future<Issue> setUpvote(String issueId, {required bool upvoted}) =>
      _write(() => _api.setUpvote(issueId, upvoted: upvoted));

  @override
  Future<void> assignTo(String issueId, String? staffId) =>
      _write(() => _api.assignTo(issueId, staffId));

  // ---------- helpers ----------

  Future<T> _write<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      _changed.add(null);
      return result;
    } catch (e, st) {
      throw mapException(e, st);
    }
  }

  /// Emits [fetch] now, every [_pollInterval], and after local writes.
  ///
  /// Once a value has been delivered, transient network errors are
  /// swallowed so a brief Wi-Fi drop does not replace content with an error.
  Stream<T> _poll<T>(Future<T> Function() fetch) {
    late final StreamController<T> controller;
    Timer? timer;
    StreamSubscription<void>? changes;
    var delivered = false;
    var inFlight = false;

    Future<void> tick() async {
      if (inFlight) return;
      inFlight = true;
      try {
        final value = await fetch();
        if (controller.isClosed) return;
        delivered = true;
        controller.add(value);
      } catch (e, st) {
        if (controller.isClosed) return;
        final failure = mapException(e, st);
        if (!(delivered && failure is NetworkFailure)) {
          controller.addError(failure, st);
        }
      } finally {
        inFlight = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        tick();
        timer = Timer.periodic(_pollInterval, (_) => tick());
        changes = _changed.stream.listen((_) => tick());
      },
      onCancel: () async {
        timer?.cancel();
        await changes?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  static String? _cleanNote(String? note) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length > maxNoteLength) {
      throw const ValidationFailure(
        'Notes can be at most $maxNoteLength characters.',
      );
    }
    return trimmed;
  }
}
