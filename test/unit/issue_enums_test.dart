import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IssueStatus transitions', () {
    test('follow the doc §7 state machine', () {
      expect(IssueStatus.reported.nextStatuses, {IssueStatus.inProgress});
      expect(IssueStatus.inProgress.nextStatuses, {IssueStatus.resolved});
      expect(IssueStatus.resolved.nextStatuses, {IssueStatus.reopened});
      expect(IssueStatus.reopened.nextStatuses, {
        IssueStatus.inProgress,
        IssueStatus.resolved,
      });
    });

    test('reject skipping straight to resolved', () {
      expect(
        IssueStatus.reported.canTransitionTo(IssueStatus.resolved),
        isFalse,
      );
    });

    test('only resolved counts as closed', () {
      expect(IssueStatus.resolved.isOpen, isFalse);
      expect(
        IssueStatus.values
            .where((s) => s != IssueStatus.resolved)
            .every((s) => s.isOpen),
        isTrue,
      );
    });
  });

  group('photo guidance', () {
    test('recommends photos where staff need to see the problem', () {
      for (final c in [
        IssueCategory.safety,
        IssueCategory.plumbing,
        IssueCategory.furniture,
        IssueCategory.cleanliness,
      ]) {
        expect(c.photoGuidance, PhotoGuidance.recommended, reason: c.name);
      }
      expect(IssueCategory.electrical.photoGuidance, PhotoGuidance.helpful);
      expect(IssueCategory.it.photoGuidance, PhotoGuidance.optional);
      expect(IssueCategory.other.photoGuidance, PhotoGuidance.optional);
    });

    test('every category has a non-empty photo tip', () {
      for (final c in IssueCategory.values) {
        expect(c.photoTip, isNotEmpty, reason: c.name);
      }
    });
  });

  group('fromValue', () {
    test('round-trips every stored value', () {
      for (final s in IssueStatus.values) {
        expect(IssueStatus.fromValue(s.value), s);
      }
      for (final p in IssuePriority.values) {
        expect(IssuePriority.fromValue(p.value), p);
      }
      for (final c in IssueCategory.values) {
        expect(IssueCategory.fromValue(c.value), c);
      }
    });

    test('falls back safely for unknown values', () {
      expect(IssueStatus.fromValue('bogus'), IssueStatus.reported);
      expect(IssuePriority.fromValue(null), IssuePriority.medium);
      expect(IssueCategory.fromValue(''), IssueCategory.other);
    });
  });
}
