import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:daco/src/formatter.dart';
import 'package:daco/src/logging.dart';
import 'package:daco/src/prettier.dart';
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  setUpAll(prettierService.start);
  tearDownAll(prettierService.stop);

  group('comments', () {
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

      group('main attribute', () {
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

      group('no_format attribute', () {
        test(
          'do not format code',
          () => expectFormatterOutput(
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
  });

  group('standalone docs', () {
    test(
      'formats markdown files',
      () => expectFormatterOutput(
        path: 'README.md',
        input: '''
# Title

a  a

```dart
const a =
  'a';
```
''',
        output: '''
# Title

a a

```dart
const a = 'a';
```
''',
      ),
    );

    test(
      'leaves invalid fenced code unchanged in markdown files',
      () => expectFormatterOutput(
        path: 'README.md',
        input: '''
# Title

```dart
void greet() {
  print('hello')
}
```
''',
        output: '''
# Title

```dart
void greet() {
  print('hello')
}
```
''',
      ),
    );

    test(
      'formats mdx files without reformatting non-dart content',
      () => expectFormatterOutput(
        path: 'docs/example.mdx',
        input: '''
---
title: Example
---

import CodeBlock from '@theme/CodeBlock'
export const answer = 42

:::info
Keep  this  spacing.
:::

<CodeExample id={1} title="Hello">
```dart
const a =
  'a';
```
</CodeExample>
''',
        output: '''
---
title: Example
---

import CodeBlock from '@theme/CodeBlock'
export const answer = 42

:::info
Keep  this  spacing.
:::

<CodeExample id={1} title="Hello">
```dart
const a = 'a';
```
</CodeExample>
''',
      ),
    );

    test(
      'formats snippet style mdx code as main body',
      () => expectFormatterOutput(
        path: 'docs/example.mdx',
        input: '''
<CodeExample id={1} title="Hello">
```dart
if (data == null) {
return;
}

await collection.saveDocument(doc);
```
</CodeExample>
''',
        output: '''
<CodeExample id={1} title="Hello">
```dart
if (data == null) {
  return;
}

await collection.saveDocument(doc);
```
</CodeExample>
''',
      ),
    );
  });

  test(
    'formats full dart files without treating declarations as snippets',
    () => expectFormatterOutput(
      input: '''
class Greeter {
  Future<void> greet() async {
    await Future<void>.value();
  }
}
''',
      output: '''
class Greeter {
  Future<void> greet() async {
    await Future<void>.value();
  }
}
''',
    ),
  );
}

final logger = TestLogger();
final prettierService = PrettierService(logger: logger.toDacoLogger());

Future<String> testFormat({
  required String input,
  String path = 'file.dart',
  int lineLength = 80,
}) {
  final formatter = DacoFormatter(
    prettierService: prettierService,
    lineLength: lineLength,
  );
  return formatter.format(input, path: path);
}

Future<void> expectFormatterOutput({
  required String input,
  required String output,
  String path = 'file.dart',
  int lineLength = 80,
}) async {
  expect(
    await testFormat(input: input, path: path, lineLength: lineLength),
    output,
  );
}

Future<void> expectSyntacticErrorAt({
  required String input,
  String path = 'file.dart',
  int? offset,
}) async {
  expect(
    () => testFormat(input: input, path: path),
    throwsA(
      isA<FormatterException>().having(
        (error) => error.errors,
        'errors',
        contains(
          isA<Diagnostic>()
              .having(
                (error) => error.diagnosticCode.type,
                'diagnosticCode.type',
                DiagnosticType.SYNTACTIC_ERROR,
              )
              .having((error) => error.offset, 'offset', offset ?? anything),
        ),
      ),
    ),
  );
}
