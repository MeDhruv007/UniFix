import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../domain/entities/issue_feedback.dart';
import '../domain/repositories/feedback_repository.dart';

/// `GET /issues/:id/feedback/me` and `POST /issues/:id/feedback`.
class FeedbackRepositoryImpl implements FeedbackRepository {
  FeedbackRepositoryImpl({required this._dio});

  final Dio _dio;

  /// Latest value per issue, re-published after a submit.
  final Map<String, StreamController<IssueFeedback?>> _subjects = {};

  @override
  Stream<IssueFeedback?> watchMyFeedback(String issueId) async* {
    yield await _fetch(issueId);
    final subject = _subjects.putIfAbsent(
      issueId,
      StreamController<IssueFeedback?>.broadcast,
    );
    yield* subject.stream;
  }

  @override
  Future<void> submitFeedback(
    String issueId, {
    required bool stillExists,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/issues/$issueId/feedback',
        data: {
          'stillExists': stillExists,
          'comment': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        },
      );
      _subjects[issueId]?.add(_fromJson(res.data!));
    } catch (e, st) {
      throw mapException(e, st);
    }
  }

  Future<IssueFeedback?> _fetch(String issueId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/issues/$issueId/feedback/me',
      );
      return _fromJson(res.data!);
    } on DioException catch (e, st) {
      // 404 means "no feedback yet", not an error.
      if (e.response?.statusCode == 404) return null;
      throw mapException(e, st);
    }
  }

  static IssueFeedback _fromJson(Map<String, dynamic> json) => IssueFeedback(
    reporterId: json['reporterId'] as String,
    stillExists: json['stillExists'] as bool,
    comment: json['comment'] as String?,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}
