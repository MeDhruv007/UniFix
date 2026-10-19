import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fixmycampus/features/reports/data/datasources/issue_api_data_source.dart';
import 'package:fixmycampus/features/reports/domain/entities/issue_enums.dart';
import 'package:fixmycampus/features/reports/domain/repositories/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late IssueApiDataSource api;
  late Directory tmp;

  setUp(() {
    adapter = FakeHttpAdapter();
    api = IssueApiDataSource(dio: fakeDio(adapter));
    tmp = Directory.systemTemp.createTempSync('fmc_ds_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
  });

  String photoFile(String name) {
    final file = File('${tmp.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
    return file.path;
  }

  group('list', () {
    setUp(
      () => adapter.reply('GET', '/issues', {
        'items': [issueJson(id: 'a'), issueJson(id: 'b')],
        'total': 57,
      }),
    );

    test('omits null filters and sends paging', () async {
      final page = await api.list(const IssueFilter(), limit: 20);

      expect(adapter.last.path, '/issues');
      expect(adapter.last.queryParameters, {'limit': 20, 'offset': 0});
      expect(adapter.last.uri.query, 'limit=20&offset=0');
      expect(page.items.map((i) => i.id), ['a', 'b']);
      expect(page.total, 57);
    });

    test('sends status, category and mine=true for "my reports"', () async {
      await api.list(
        const IssueFilter(
          status: IssueStatus.inProgress,
          category: IssueCategory.it,
          reporterId: 'u1',
        ),
        limit: 10,
        offset: 30,
      );

      expect(adapter.last.queryParameters, {
        'status': 'inProgress',
        'category': 'it',
        'mine': true,
        'limit': 10,
        'offset': 30,
      });
      expect(adapter.last.uri.queryParameters, {
        'status': 'inProgress',
        'category': 'it',
        'mine': 'true',
        'limit': '10',
        'offset': '30',
      });
    });

    test('never sends the reporter id itself', () async {
      await api.list(const IssueFilter(reporterId: 'u1'), limit: 20);

      expect(adapter.last.uri.toString(), isNot(contains('u1')));
    });
  });

  test('get reads /issues/:id', () async {
    adapter.reply('GET', '/issues/i9', issueJson(id: 'i9'));

    expect((await api.get('i9')).id, 'i9');
  });

  test('updates reads /issues/:id/updates in order', () async {
    adapter.reply('GET', '/issues/i1/updates', [
      issueUpdateJson(id: 'h1', action: 'created'),
      issueUpdateJson(id: 'h2'),
    ]);

    final updates = await api.updates('i1');

    expect(updates.map((u) => u.id), ['h1', 'h2']);
    expect(updates.first.action, IssueUpdateAction.created);
  });

  group('create', () {
    test('posts trimmed multipart fields and photos', () async {
      adapter.reply('POST', '/issues', issueJson(id: 'new'), status: 201);

      final issue = await api.create(
        NewIssueInput(
          title: '  Fan not working  ',
          description: ' The ceiling fan does not start. ',
          category: IssueCategory.electrical,
          buildingId: 'engineering-block',
          locationDetail: ' Room 204 ',
          localPhotoPaths: [photoFile('a.JPG'), photoFile('b.png')],
        ),
      );

      expect(issue.id, 'new');
      expect(adapter.last.method, 'POST');
      expect(adapter.last.path, '/issues');
      final form = adapter.last.data as FormData;
      expect(Map.fromEntries(form.fields), {
        'title': 'Fan not working',
        'description': 'The ceiling fan does not start.',
        'category': 'electrical',
        'buildingId': 'engineering-block',
        'locationDetail': 'Room 204',
      });
      expect(form.fields.map((f) => f.key), isNot(contains('campusId')));
      expect(form.files.map((f) => f.key), ['photos', 'photos']);
      expect(form.files.map((f) => f.value.contentType?.mimeType), [
        'image/jpeg',
        'image/png',
      ]);
      expect(adapter.last.contentType, startsWith('multipart/form-data'));
    });

    test('sends no photo parts when there are none', () async {
      adapter.reply('POST', '/issues', issueJson(), status: 201);

      await api.create(
        const NewIssueInput(
          title: 'Broken tap',
          description: 'Tap keeps running all day.',
          category: IssueCategory.plumbing,
          buildingId: 'hostel',
          locationDetail: 'Block A',
        ),
      );

      expect((adapter.last.data as FormData).files, isEmpty);
    });
  });

  test('updateStatus patches from/to/note', () async {
    adapter.reply('PATCH', '/issues/i1/status', issueJson(status: 'resolved'));

    final issue = await api.updateStatus(
      'i1',
      from: IssueStatus.inProgress,
      to: IssueStatus.resolved,
      note: 'Fixed',
    );

    expect(issue.status, IssueStatus.resolved);
    expect(adapter.last.data, {
      'from': 'inProgress',
      'to': 'resolved',
      'note': 'Fixed',
    });
  });

  test('updatePriority patches from/to', () async {
    adapter.reply('PATCH', '/issues/i1/priority', issueJson(priority: 'high'));

    await api.updatePriority(
      'i1',
      from: IssuePriority.medium,
      to: IssuePriority.high,
    );

    expect(adapter.last.data, {'from': 'medium', 'to': 'high'});
  });

  test('assignToMe posts to /assign without a body', () async {
    adapter.reply('POST', '/issues/i1/assign', issueJson(assignedTo: 'a1'));

    expect((await api.assignToMe('i1')).assignedTo, 'a1');
    expect(adapter.last.data, isNull);
  });

  test('addResolutionPhotos posts multipart photos', () async {
    adapter.reply('POST', '/issues/i1/resolution-photos', issueJson());

    await api.addResolutionPhotos('i1', [photoFile('r.webp')]);

    final form = adapter.last.data as FormData;
    expect(form.fields, isEmpty);
    expect(form.files.single.key, 'photos');
    expect(form.files.single.value.contentType?.mimeType, 'image/webp');
  });

  group('stats', () {
    test('parses the v1.1 shape', () async {
      adapter.reply('GET', '/issues/stats', {
        'reported': 4,
        'inProgress': 2,
        'resolved': 9,
        'reopened': 1,
        'total': 16,
        'open': 7,
        'urgent': 1,
        'unassigned': 3,
        'createdLast24h': 2,
        'resolvedThisWeek': 5,
        'avgResolutionHours': 57.6,
        'openByCategory': {'electrical': 4, 'plumbing': 3},
      });

      final s = await api.stats();
      expect(adapter.last.queryParameters, isEmpty);
      expect(s.open, 7);
      expect(s.urgent, 1);
      expect(s.unassigned, 3);
      expect(s.createdLast24h, 2);
      expect(s.resolvedThisWeek, 5);
      expect(s.avgResolutionHours, 57.6);
      expect(s.countFor(IssueStatus.resolved), 9);
      expect(s.openByCategory[IssueCategory.electrical], 4);
      // Every category is present, missing ones as zero.
      expect(s.openByCategory.length, IssueCategory.values.length);
      expect(s.openByCategory[IssueCategory.safety], 0);
    });

    test('tolerates the v1 shape and derives open', () async {
      adapter.reply('GET', '/issues/stats', {
        'reported': 4,
        'inProgress': 2,
        'resolved': 9,
        'reopened': 1,
        'total': 16,
      });

      final s = await api.stats();
      expect(s.open, 7);
      expect(s.avgResolutionHours, isNull);
    });

    test('mine adds mine=true', () async {
      adapter.reply('GET', '/issues/stats', {'total': 1});
      await api.stats(mine: true);
      expect(adapter.last.queryParameters, {'mine': true});
    });
  });

  test('v1.1 list params: q, open, priority, assigned, sort', () async {
    adapter.reply('GET', '/issues', {'items': [], 'total': 0});
    await api.list(
      const IssueFilter(
        query: '  fan ',
        openOnly: true,
        priority: IssuePriority.urgent,
        assigned: false,
        sort: IssueSort.oldest,
      ),
      limit: 20,
    );
    expect(adapter.last.queryParameters, {
      'q': 'fan',
      'open': true,
      'priority': 'urgent',
      'assigned': false,
      'sort': 'oldest',
      'limit': 20,
      'offset': 0,
    });
  });

  test('staff parses the admin list', () async {
    adapter.reply('GET', '/staff', [
      {'id': 'a1', 'displayName': 'S. Patel'},
    ]);
    expect(await api.staff(), const [
      StaffMember(id: 'a1', displayName: 'S. Patel'),
    ]);
  });

  test('assignTo sends assigneeId, null to unassign', () async {
    adapter.reply('POST', '/issues/i1/assign', issueJson());
    await api.assignTo('i1', 'a1');
    expect(adapter.last.data, {'assigneeId': 'a1'});
    await api.assignTo('i1', null);
    expect(adapter.last.data, {'assigneeId': null});
  });

  test('errors surface as DioExceptions for the repository to map', () async {
    adapter.fail('GET', '/issues/x', 404, code: 'NOT_FOUND', message: 'Nope');

    await expectLater(
      api.get('x'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
  });
}
