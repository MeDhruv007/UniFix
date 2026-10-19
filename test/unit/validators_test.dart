import 'package:fixmycampus/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('not-an-email'), isNotNull);
    expect(Validators.email('  student@adit.ac.in  '), isNull);
  });

  test('password needs at least 8 characters and one number', () {
    expect(Validators.password(''), isNotNull);
    expect(Validators.password('short1'), isNotNull);
    expect(Validators.password('longenough'), isNotNull);
    expect(Validators.password('longenough1'), isNull);
    expect(Validators.password('12345678'), isNull);
  });

  test('issue title is trimmed and bounded', () {
    expect(Validators.issueTitle('   '), isNotNull);
    expect(Validators.issueTitle('Fan'), isNotNull);
    expect(Validators.issueTitle('Fan broken in 204'), isNull);
    expect(Validators.issueTitle('x' * 101), isNotNull);
  });

  test('description bounds', () {
    expect(Validators.issueDescription('too short'), isNotNull);
    expect(
      Validators.issueDescription('The ceiling fan does not start.'),
      isNull,
    );
  });

  test('optional note allows empty but caps length', () {
    expect(Validators.optionalNote(null), isNull);
    expect(Validators.optionalNote(''), isNull);
    expect(Validators.optionalNote('x' * 501), isNotNull);
  });
}
