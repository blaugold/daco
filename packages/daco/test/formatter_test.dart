import 'package:analyzer/error/error.dart';
import 'package:daco/src/formatter.dart';
import 'package:daco/src/logging.dart';
import 'package:daco/src/prettier.dart';
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('comments', () {
    setUpAll(prettierService.start);
    tearDownAll(prettierService.stop);

    test(
      'single line comment',
      () => expectFormatterOutput(
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
      () => expectFormatterOutput(
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
        () => expectFormatterOutput(
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
        () => expectFormatterOutput(
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
        () => expectFormatterOutput(
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
        () => expectFormatterOutput(
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
        () => expectFormatterOutput(
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
        () => expectFormatterOutput(
          input: '''
/// ```dart
///  const a = 'a';
/// ```
///
/// ```dart
///  const b = 'b';
/// ```
const a = 'a';
''',
          output: '''
/// ```dart
/// const a = 'a';
/// ```
///
/// ```dart
/// const b = 'b';
/// ```
const a = 'a';
''',
        ),
      );

      test(
        'fenced code is formatted to correct length',
        () => expectFormatterOutput(
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
        'supports nested fenced code',
        () => expectFormatterOutput(
          input: '''
/// 1. A
///    ```dart
///    const a =
///       'a';
///
///    const b = 'b';
///    ```
const a = 'a';
''',
          output: '''
/// 1. A
///
///    ```dart
///    const a = 'a';
///
///    const b = 'b';
///    ```
const a = 'a';
''',
        ),
      );

      test(
        'comments are formatted',
        () => expectFormatterOutput(
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

      group('ignore attribute', () {
        test(
          'do not format code',
          () => expectFormatterOutput(
            input: '''
/// ```dart ignore
/// /// a  a
/// const a = 'a';
/// ```
const a = 'a';
''',
            output: '''
/// ```dart ignore
/// /// a  a
/// const a = 'a';
/// ```
const a = 'a';
''',
          ),
        );

        test(
          'do not parse code',
          () => expectFormatterOutput(
            input: '''
/// ```dart ignore
/// a
/// ```
const a = 'a';
''',
            output: '''
/// ```dart ignore
/// a
/// ```
const a = 'a';
''',
          ),
        );
      });

      group('attribute main', () {
        test(
          'check code for syntactic errors',
          () => expectSyntacticErrorAt(
            input: '''
/// ```dart main
/// const a = 'a'
/// ```
const a = 'a';
''',
            offset: 31,
          ),
        );

        test(
          'handle empty code block',
          () => expectFormatterOutput(
            input: '''
/// ```dart main
/// ```
const a = 'a';
''',
            output: '''
/// ```dart main
/// ```
const a = 'a';
''',
          ),
        );

        test(
          'format code as part of a function',
          () => expectFormatterOutput(
            input: '''
/// ```dart main
/// const a =
///   'a';
/// ```
const a = 'a';
''',
            output: '''
/// ```dart main
/// const a = 'a';
/// ```
const a = 'a';
''',
          ),
        );

        test(
          'end of line comment in main',
          () => expectFormatterOutput(
            input: '''
/// ```dart main
/// // ...
/// ```
const a = 'a';
''',
            output: '''
/// ```dart main
/// // ...
/// ```
const a = 'a';
''',
          ),
        );
      });
    });
  });
}

final logger = TestLogger();
final prettierService = PrettierService(logger: logger.toDacoLogger());

Future<String> testFormat({
  required String input,
  int lineLength = 80,
}) async {
  final formatter = DacoFormatter(
    prettierService: prettierService,
    lineLength: lineLength,
  );
  return formatter.format(input);
}

Future<void> expectFormatterOutput({
  required String input,
  required String output,
  int lineLength = 80,
}) async {
  expect(await testFormat(input: input, lineLength: lineLength), output);
}

Future<void> expectSyntacticErrorAt({
  required String input,
  int? offset,
}) async {
  expect(
    () => testFormat(input: input),
    throwsA(
      isA<FormatterException>().having(
        (error) => error.errors,
        'errors',
        contains(
          isA<AnalysisError>()
              .having(
                (error) => error.errorCode.type,
                'errorCode.type',
                ErrorType.SYNTACTIC_ERROR,
              )
              .having(
                (error) => error.offset,
                'offset',
                offset ?? anything,
              ),
        ),
      ),
    ),
  );
}
