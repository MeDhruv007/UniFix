import 'package:fixmycampus/features/reports/data/datasources/issue_api_data_source.dart';
import 'package:fixmycampus/features/reports/data/models/issue_model.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late IssueApiDataSource api;

  setUp(() {
    adapter = FakeHttpAdapter();
    api = IssueApiDataSource(dio: fakeDio(adapter));
  });

  group('Issue JSON', () {
    test('reads upvoteCount and upvotedByMe', () {
      final issue = IssueModel.fromJson({
        ...issueJson(),
        'upvoteCount': 4,
        'upvotedByMe': true,
      });
      expect(issue.upvoteCount, 4);
      expect(issue.upvotedByMe, isTrue);
    });

    test('defaults to 0 / false for servers without upvotes', () {
      final issue = IssueModel.fromJson(issueJson());
      expect(issue.upvoteCount, 0);
      expect(issue.upvotedByMe, isFalse);
    });
  });

  group('setUpvote', () {
    test('POST adds the upvote', () async {
      adapter.reply('POST', '/issues/i1/upvote', {
        ...issueJson(),
        'upvoteCount': 2,
        'upvotedByMe': true,
      });
      final issue = await api.setUpvote('i1', upvoted: true);
      expect(adapter.last.method, 'POST');
      expect(issue.upvoteCount, 2);
      expect(issue.upvotedByMe, isTrue);
    });

    test('DELETE takes it back', () async {
      adapter.reply('DELETE', '/issues/i1/upvote', {
        ...issueJson(),
        'upvoteCount': 1,
        'upvotedByMe': false,
      });
      final issue = await api.setUpvote('i1', upvoted: false);
      expect(adapter.last.method, 'DELETE');
      expect(issue.upvotedByMe, isFalse);
    });
  });

  test('sort=popular is sent only for the popular sort', () async {
    adapter.reply('GET', '/issues', {'items': [], 'total': 0});
    await api.list(const IssueFilter(sort: IssueSort.popular), limit: 20);
    expect(adapter.last.queryParameters['sort'], 'popular');
    await api.list(const IssueFilter(), limit: 20);
    expect(adapter.last.queryParameters.containsKey('sort'), isFalse);
  });
}
