import 'package:daco/src/formatter.dart';
import 'package:daco/src/prettier.dart';
import 'package:test/test.dart';

void main() {
  group('comments', () {
    setUpAll(prettierService.start);
    tearDownAll(prettierService.stop);

    test(
      'single line comment',
      () => commentsFormattingTest(
        input: '''
/// a  a
const a = 'a';
''',
        output: '''
/// a a
const a = 'a';
''',
      ),
    );

    test(
      'multi line comment',
      () => commentsFormattingTest(
        input: '''
/// a  a
///
/// a  a
const a = 'a';
''',
        output: '''
/// a a
///
/// a a
const a = 'a';
''',
      ),
    );

    group('dart doc tags', () {
      test(
        'single instance before paragraph',
        () => commentsFormattingTest(
          input: '''
/// {@a}
/// a
const a = 'a';
''',
          output: '''
/// {@a}
/// a
const a = 'a';
''',
        ),
      );

      test(
        'single instance after paragraph',
        () => commentsFormattingTest(
          input: '''
/// a
/// {@a}
const a = 'a';
''',
          output: '''
/// a
/// {@a}
const a = 'a';
''',
        ),
      );

      test(
        'multiple instances before paragraph',
        () => commentsFormattingTest(
          input: '''
/// {@a}
/// {@a}
/// a
const a = 'a';
''',
          output: '''
/// {@a}
/// {@a}
/// a
const a = 'a';
''',
        ),
      );

      test(
        'multiple instances after paragraph',
        () => commentsFormattingTest(
          input: '''
/// a
/// {@a}
/// {@a}
const a = 'a';
''',
          output: '''
/// a
/// {@a}
/// {@a}
const a = 'a';
''',
        ),
      );
    });

    group('embedded Dart code', () {
      test(
        'single instance of fenced code',
        () => commentsFormattingTest(
          input: '''
/// ```dart
///  const a = 'a';
/// ```
const a = 'a';
''',
          output: '''
/// ```dart
/// const a = 'a';
/// ```
const a = 'a';
''',
        ),
      );

      test(
        'multiple instances of fenced code',
        () => commentsFormattingTest(
          input: '''
/// ```dart
///  const a = 'a';
/// ```
///
/// ```dart
///  const a = 'a';
/// ```
const a = 'a';
''',
          output: '''
/// ```dart
/// const a = 'a';
/// ```
///
/// ```dart
/// const a = 'a';
/// ```
const a = 'a';
''',
        ),
      );

      test(
        'fenced code is formatted to correct length',
        () => commentsFormattingTest(
          lineLength: 30,
          input: '''
/// ```dart
/// const a = 'aaaaaaaaaaaaaa';
/// ```
const a = 'a';
''',
          output: '''
/// ```dart
/// const a =
///     'aaaaaaaaaaaaaa';
/// ```
const a = 'a';
''',
        ),
      );

      test(
        'comments are formatted',
        () => commentsFormattingTest(
          input: '''
/// ```dart
/// /// a  a
/// const a = 'a';
/// ```
const a = 'a';
''',
          output: '''
/// ```dart
/// /// a a
/// const a = 'a';
/// ```
const a = 'a';
''',
        ),
      );

      test(
        'do not format code tagged with no_format',
        () => commentsFormattingTest(
          input: '''
/// ```dart no_format
/// /// a  a
/// const a = 'a';
/// ```
const a = 'a';
''',
          output: '''
/// ```dart no_format
/// /// a  a
/// const a = 'a';
/// ```
const a = 'a';
''',
        ),
      );
    });
  });
}

final prettierService = PrettierService();

Future<void> commentsFormattingTest({
  required String input,
  required String output,
  int lineLength = 80,
}) async {
  final formatter = DacoFormatter(
    prettierService: prettierService,
    lineLength: lineLength,
  );
  expect(await formatter.format(input), output);
}
