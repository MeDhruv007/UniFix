import 'package:fixmycampus/features/reports/data/models/issue_model.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/api_fixtures.dart';

void main() {
  group('IssueModel.fromJson', () {
    test('maps every field of the API Issue object', () {
      final issue = IssueModel.fromJson(
        issueJson(
          status: 'resolved',
          priority: 'urgent',
          category: 'plumbing',
          resolutionNote: 'Replaced the capacitor',
          resolutionPhotoPaths: ['issues/i1/resolution/r1.jpg'],
          assignedTo: 'admin1',
          resolvedAt: '2026-10-16T10:00:00.000Z',
          reopenCount: 2,
        ),
      );

      expect(issue.id, 'i1');
      expect(issue.campusId, 'adit-main');
      expect(issue.title, 'Fan not working in Room 204');
      expect(issue.description, 'The ceiling fan does not start.');
      expect(issue.category, IssueCategory.plumbing);
      expect(issue.buildingId, 'engineering-block');
      expect(issue.locationDetail, 'Second floor, Room 204');
      expect(issue.photoPaths, ['issues/i1/report/p1.jpg']);
      expect(issue.reporterId, 'u1');
      expect(issue.reporterDisplayName, 'Asha Patel');
      expect(issue.status, IssueStatus.resolved);
      expect(issue.priority, IssuePriority.urgent);
      expect(issue.assignedTo, 'admin1');
      expect(issue.resolutionNote, 'Replaced the capacitor');
      expect(issue.resolutionPhotoPaths, ['issues/i1/resolution/r1.jpg']);
      expect(issue.reopenCount, 2);
    });

    test('parses ISO-8601 UTC timestamps into local DateTimes', () {
      final issue = IssueModel.fromJson(
        issueJson(resolvedAt: '2026-10-16T10:00:00.000Z'),
      );

      expect(issue.createdAt!.isUtc, isFalse);
      expect(issue.createdAt, DateTime.utc(2026, 10, 15, 14, 3).toLocal());
      expect(issue.updatedAt, DateTime.utc(2026, 10, 15, 15, 30).toLocal());
      expect(issue.resolvedAt, DateTime.utc(2026, 10, 16, 10).toLocal());
    });

    test('keeps nullable fields null', () {
      final issue = IssueModel.fromJson(issueJson());

      expect(issue.assignedTo, isNull);
      expect(issue.resolutionNote, isNull);
      expect(issue.resolvedAt, isNull);
      expect(issue.resolutionPhotoPaths, isEmpty);
    });

    test('tolerates null lists, timestamps and counters', () {
      final json = issueJson()
        ..['photoPaths'] = null
        ..['resolutionPhotoPaths'] = null
        ..['reporterDisplayName'] = null
        ..['createdAt'] = null
        ..['updatedAt'] = null
        ..['reopenCount'] = null;

      final issue = IssueModel.fromJson(json);

      expect(issue.photoPaths, isEmpty);
      expect(issue.resolutionPhotoPaths, isEmpty);
      expect(issue.reporterDisplayName, isNull);
      expect(issue.createdAt, isNull);
      expect(issue.updatedAt, isNull);
      expect(issue.reopenCount, 0);
    });

    test('unknown enum strings fall back to safe defaults', () {
      final issue = IssueModel.fromJson(
        issueJson(status: 'archived', priority: 'critical', category: 'hvac'),
      );

      expect(issue.status, IssueStatus.reported);
      expect(issue.priority, IssuePriority.medium);
      expect(issue.category, IssueCategory.other);
    });

    test('accepts every contract enum value', () {
      for (final s in IssueStatus.values) {
        expect(IssueModel.fromJson(issueJson(status: s.value)).status, s);
      }
      for (final p in IssuePriority.values) {
        expect(IssueModel.fromJson(issueJson(priority: p.value)).priority, p);
      }
      for (final c in IssueCategory.values) {
        expect(IssueModel.fromJson(issueJson(category: c.value)).category, c);
      }
    });
  });

  group('IssueUpdateModel.fromJson', () {
    test('maps a status change', () {
      final update = IssueUpdateModel.fromJson(issueUpdateJson());

      expect(update.id, 'h1');
      expect(update.actorId, 'admin1');
      expect(update.action, IssueUpdateAction.statusChanged);
      expect(update.oldStatus, IssueStatus.reported);
      expect(update.newStatus, IssueStatus.inProgress);
      expect(update.oldPriority, isNull);
      expect(update.newPriority, isNull);
      expect(update.note, 'Electrician assigned');
      expect(update.createdAt, DateTime.utc(2026, 10, 15, 14, 3).toLocal());
      expect(update.createdAt!.isUtc, isFalse);
    });

    test('maps a priority change', () {
      final update = IssueUpdateModel.fromJson(
        issueUpdateJson(
          action: 'priorityChanged',
          oldStatus: null,
          newStatus: null,
          oldPriority: 'medium',
          newPriority: 'urgent',
          note: null,
        ),
      );

      expect(update.action, IssueUpdateAction.priorityChanged);
      expect(update.oldStatus, isNull);
      expect(update.newStatus, isNull);
      expect(update.oldPriority, IssuePriority.medium);
      expect(update.newPriority, IssuePriority.urgent);
      expect(update.note, isNull);
    });

    test('accepts every contract action', () {
      for (final a in IssueUpdateAction.values) {
        expect(
          IssueUpdateModel.fromJson(issueUpdateJson(action: a.value)).action,
          a,
        );
      }
    });

    test('unknown action and missing actor fall back', () {
      final json = issueUpdateJson(action: 'deleted')
        ..['actorId'] = null
        ..['createdAt'] = null;

      final update = IssueUpdateModel.fromJson(json);

      expect(update.action, IssueUpdateAction.commented);
      expect(update.actorId, '');
      expect(update.createdAt, isNull);
    });

    test('unknown status values fall back instead of being dropped', () {
      final update = IssueUpdateModel.fromJson(
        issueUpdateJson(oldStatus: 'archived', newPriority: 'critical'),
      );

      expect(update.oldStatus, IssueStatus.reported);
      expect(update.newPriority, IssuePriority.medium);
    });
  });
}
