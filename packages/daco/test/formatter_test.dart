import 'package:daco/src/formatter.dart';
import 'package:daco/src/prettier.dart';
import 'package:dart_style/dart_style.dart';
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
          lineLength: 30,
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
    });
  });
}

final prettierService = PrettierService();

Future<void> commentsFormattingTest({
  required String input,
  required String output,
  int lineLength = 80,
}) async {
  final dartFormatter = DartFormatter(pageWidth: lineLength);
  final actual = await formatCommentsInSource(
    input,
    dartFormatter: dartFormatter,
    prettierService: prettierService,
  );
  expect(actual, output);
}
