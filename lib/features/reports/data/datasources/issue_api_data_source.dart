import 'package:dio/dio.dart';

import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import '../../domain/entities/issue_update.dart';
import '../../domain/repositories/issue_repository.dart';
import '../models/issue_model.dart';

/// `/issues` endpoints (docs/API.md). Throws [DioException]s; the
/// repository maps them to failures.
class IssueApiDataSource {
  IssueApiDataSource({required this._dio});

  final Dio _dio;

  Future<({List<Issue> items, int total})> list(
    IssueFilter filter, {
    required int limit,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/issues',
      queryParameters: {
        'status': ?filter.status?.value,
        'category': ?filter.category?.value,
        if (filter.reporterId != null) 'mine': true,
        if (filter.query?.trim() case final q? when q.isNotEmpty) 'q': q,
        if (filter.openOnly) 'open': true,
        'priority': ?filter.priority?.value,
        if (filter.assigned != null) 'assigned': filter.assigned,
        if (filter.assignedToMe) 'assignedToMe': true,
        if (filter.sort == IssueSort.oldest) 'sort': 'oldest',
        if (filter.sort == IssueSort.popular) 'sort': 'popular',
        'limit': limit,
        'offset': offset,
      },
    );
    final body = res.data!;
    return (
      items: (body['items'] as List<dynamic>)
          .map((e) => IssueModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (body['total'] as num).toInt(),
    );
  }

  Future<Issue> get(String id) async => IssueModel.fromJson(
    (await _dio.get<Map<String, dynamic>>('/issues/$id')).data!,
  );

  Future<List<IssueUpdate>> updates(String id) async {
    final res = await _dio.get<List<dynamic>>('/issues/$id/updates');
    return res.data!
        .map((e) => IssueUpdateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Multipart create: the server stores photos and the issue (plus its
  /// `created` history entry) in one transaction.
  Future<Issue> create(NewIssueInput input) async {
    final form = FormData.fromMap({
      'title': input.title.trim(),
      'description': input.description.trim(),
      'category': input.category.value,
      'buildingId': input.buildingId,
      'locationDetail': input.locationDetail.trim(),
      'photos': [for (final path in input.localPhotoPaths) await _file(path)],
    });
    return _issue(await _dio.post<Map<String, dynamic>>('/issues', data: form));
  }

  Future<Issue> updateStatus(
    String id, {
    required IssueStatus from,
    required IssueStatus to,
    String? note,
  }) async => _issue(
    await _dio.patch<Map<String, dynamic>>(
      '/issues/$id/status',
      data: {'from': from.value, 'to': to.value, 'note': note},
    ),
  );

  Future<Issue> updatePriority(
    String id, {
    required IssuePriority from,
    required IssuePriority to,
  }) async => _issue(
    await _dio.patch<Map<String, dynamic>>(
      '/issues/$id/priority',
      data: {'from': from.value, 'to': to.value},
    ),
  );

  /// "Me too": idempotent set/remove of the caller's upvote.
  Future<Issue> setUpvote(String id, {required bool upvoted}) async => _issue(
    upvoted
        ? await _dio.post<Map<String, dynamic>>('/issues/$id/upvote')
        : await _dio.delete<Map<String, dynamic>>('/issues/$id/upvote'),
  );

  Future<Issue> assignToMe(String id) async =>
      _issue(await _dio.post<Map<String, dynamic>>('/issues/$id/assign'));

  Future<Issue> addResolutionPhotos(String id, List<String> localPaths) async {
    final form = FormData.fromMap({
      'photos': [for (final path in localPaths) await _file(path)],
    });
    return _issue(
      await _dio.post<Map<String, dynamic>>(
        '/issues/$id/resolution-photos',
        data: form,
      ),
    );
  }

  Future<IssueStats> stats({bool mine = false}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/issues/stats',
      queryParameters: {if (mine) 'mine': true},
    );
    return IssueStatsModel.fromJson(res.data!);
  }

  Future<List<StaffMember>> staff() async {
    final res = await _dio.get<List<dynamic>>('/staff');
    return [
      for (final e in res.data!.cast<Map<String, dynamic>>())
        StaffMember(
          id: e['id'] as String,
          displayName: e['displayName'] as String,
        ),
    ];
  }

  /// [staffId] null unassigns.
  Future<Issue> assignTo(String id, String? staffId) async => _issue(
    await _dio.post<Map<String, dynamic>>(
      '/issues/$id/assign',
      data: {'assigneeId': staffId},
    ),
  );

  Issue _issue(Response<Map<String, dynamic>> res) =>
      IssueModel.fromJson(res.data!);

  Future<MultipartFile> _file(String path) async {
    final ext = path.split('.').last.toLowerCase();
    final subtype = switch (ext) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    return MultipartFile.fromFile(
      path,
      contentType: DioMediaType('image', subtype),
    );
  }
}
