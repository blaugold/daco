import 'package:daco/src/source.dart';
import 'package:test/test.dart';

void main() {
  group('DartSource', () {
    group('compute documentation comments', () {
      test('empty source', () {
        final source = DartSource(text: '');
        expect(source.enclosedSources(), isEmpty);
        expect(source.documentationComments(), isEmpty);
      });

      test('source without comments', () {
        final source = DartSource(
          text: '''
const a = 'a';
''',
        );
        expect(source.enclosedSources(), isEmpty);
        expect(source.documentationComments(), isEmpty);
      });

      test('source with single comment', () {
        final source = DartSource(
          text: '''
/// A
const a = 'a';
''',
        );

        final comments = source.documentationComments();
        expect(comments, source.enclosedSources());
        expect(comments, hasLength(1));
        expect(comments.first.text, 'A\n');
      });

      test('source with multiple comments', () {
        final source = DartSource(
          text: '''
/// A
const a = 'a';

/// B
const b = 'b';
''',
        );

        final comments = source.documentationComments();
        expect(comments, source.enclosedSources());
        expect(comments, hasLength(2));
        expect(comments[0].text, 'A\n');
        expect(comments[1].text, 'B\n');
      });

      test('multi-line comments', () {
        final source = DartSource(
          text: '''
/// A
/// B
const a = 'a';
''',
        );

        final comment = source.documentationComments().first;
        expect(comment.text, 'A\nB\n');
        expect(comment.translateOffset(0), 4);
        expect(comment.translateOffset(2), 10);
      });

      test('strips the first space of each line if it exists', () {
        final source = DartSource(
          text: '''
/// A
///B
const a = 'a';
''',
        );

        final comment = source.documentationComments().first;
        expect(comment.text, 'A\nB\n');
        expect(comment.translateOffset(0), 4);
        expect(comment.translateOffset(2), 9);
      });

      test('indented comments', () {
        final source = DartSource(
          text: '''
  /// A
  /// B
const a = 'a';
''',
        );

        final comment = source.documentationComments().first;
        expect(comment.text, 'A\nB\n');
        expect(comment.translateOffset(0), 6);
        expect(comment.translateOffset(2), 14);
      });
    });

    group('compute analysis errors', () {
      test('in root source', () {
        final source = DartSource(
          text: '''
const a = 'a'
''',
        );

        final analysisErrors = source.analysisErrors();
        expect(analysisErrors, hasLength(1));
        expect(analysisErrors.first.source.contents.data, source.text);
        expect(analysisErrors.first.offset, 10);
        expect(analysisErrors.first.length, 3);
        expect(analysisErrors.first.message, "Expected to find ';'.");
      });

      test('in enclosed source', () {
        final source = MarkdownSource(
          text: '''
```dart
const a = 'a'
```
''',
        );

        final analysisErrors = source.dartCodeBlocks().first.analysisErrors();
        expect(analysisErrors, hasLength(1));
        expect(analysisErrors.first.source.contents.data, source.text);
        expect(analysisErrors.first.offset, 18);
        expect(analysisErrors.first.length, 3);
        expect(analysisErrors.first.message, "Expected to find ';'.");
      });
    });

    group('replace enclosed sources', () {
      test('nothing', () {
        const text = '''
const a = 'a';
''';
        final source = DartSource(
          text: text,
        );

        expect(source.replaceEnclosedSources({}), text);
      });

      test('single comment', () {
        final source = DartSource(
          text: '''
/// A
const a = 'a';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments().first: 'B',
          }),
          '''
/// B
const a = 'a';
''',
        );
      });

      test('multiple comment', () {
        final source = DartSource(
          text: '''
/// A
const a = 'a';

/// B
const b = 'b';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments()[0]: 'C',
            source.documentationComments()[1]: 'D',
          }),
          '''
/// C
const a = 'a';

/// D
const b = 'b';
''',
        );
      });

      test('one of multiple comment', () {
        final source = DartSource(
          text: '''
/// A
const a = 'a';

/// B
const b = 'b';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments()[0]: 'C',
          }),
          '''
/// C
const a = 'a';

/// B
const b = 'b';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments()[1]: 'D',
          }),
          '''
/// A
const a = 'a';

/// D
const b = 'b';
''',
        );
      });

      test('multi line comments', () {
        final source = DartSource(
          text: '''
/// A
/// B
const a = 'a';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments().first: 'C',
          }),
          '''
/// C
const a = 'a';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments().first: 'C\nD',
          }),
          '''
/// C
/// D
const a = 'a';
''',
        );
      });

      test('trims last line empty', () {
        final source = DartSource(
          text: '''
/// A
const a = 'a';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments().first: 'B\n',
          }),
          '''
/// B
const a = 'a';
''',
        );
      });

      test('empty replacement', () {
        final source = DartSource(
          text: '''
/// A
const a = 'a';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments().first: '',
          }),
          '''
///
const a = 'a';
''',
        );
      });

      test('indented comment', () {
        final source = DartSource(
          text: '''
  /// A
const a = 'a';
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.documentationComments().first: 'B',
          }),
          '''
  /// B
const a = 'a';
''',
        );
      });
    });
  });

  group('MarkdownSource', () {
    group('compute Dart code blocks', () {
      test('empty source', () {
        final source = MarkdownSource(text: '');
        expect(source.enclosedSources(), isEmpty);
        expect(source.dartCodeBlocks(), isEmpty);
      });

      test('source without code blocks', () {
        final source = MarkdownSource(
          text: '''
A
''',
        );
        expect(source.enclosedSources(), isEmpty);
        expect(source.dartCodeBlocks(), isEmpty);
      });

      test('source with single code block', () {
        final source = MarkdownSource(
          text: '''
```dart
a
```
''',
        );

        final codeBlocks = source.dartCodeBlocks();
        expect(codeBlocks, source.enclosedSources());
        expect(codeBlocks, hasLength(1));
        expect(codeBlocks.first.text, 'a\n');
      });

      test('multi line code blocks', () {
        final source = MarkdownSource(
          text: '''
```dart
a
```
```dart
b
```
''',
        );

        final codeBlocks = source.dartCodeBlocks();
        expect(codeBlocks, source.enclosedSources());
        expect(codeBlocks, hasLength(2));
        expect(codeBlocks[0].text, 'a\n');
        expect(codeBlocks[1].text, 'b\n');
      });

      test('source with multiple code blocks', () {
        final source = MarkdownSource(
          text: '''
```dart
a
b
```
''',
        );

        final codeBlock = source.dartCodeBlocks().first;
        expect(codeBlock.text, 'a\nb\n');
        expect(codeBlock.translateOffset(0), 8);
        expect(codeBlock.translateOffset(2), 10);
      });

      test('indented code blocks', () {
        final source = MarkdownSource(
          text: '''
  ```dart
  a
  b
  ```
''',
        );

        final codeBlock = source.dartCodeBlocks().first;
        expect(codeBlock.text, 'a\nb\n');
        expect(codeBlock.translateOffset(0), 12);
        expect(codeBlock.translateOffset(2), 16);
      });
    });

    group('replace enclosed sources', () {
      test('nothing', () {
        const text = '''
A
''';
        final source = MarkdownSource(
          text: text,
        );

        expect(source.replaceEnclosedSources({}), text);
      });

      test('single code block', () {
        final source = MarkdownSource(
          text: '''
```dart
a
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks().first: 'b',
          }),
          '''
```dart
b
```
''',
        );
      });

      test('multiple code blocks', () {
        final source = MarkdownSource(
          text: '''
```dart
a
```
```dart
b
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[0]: 'c',
            source.dartCodeBlocks()[1]: 'd',
          }),
          '''
```dart
c
```
```dart
d
```
''',
        );
      });

      test('one of multiple code blocks', () {
        final source = MarkdownSource(
          text: '''
```dart
a
```
```dart
b
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[0]: 'c',
          }),
          '''
```dart
c
```
```dart
b
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[1]: 'c',
          }),
          '''
```dart
a
```
```dart
c
```
''',
        );
      });

      test('multi-line code blocks', () {
        final source = MarkdownSource(
          text: '''
```dart
a
b
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[0]: 'c',
          }),
          '''
```dart
c
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[0]: 'c\nd',
          }),
          '''
```dart
c
d
```
''',
        );
      });

      test('trim last empty line', () {
        final source = MarkdownSource(
          text: '''
```dart
a
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[0]: 'b\n',
          }),
          '''
```dart
b
```
''',
        );
      });

      test('empty replacement', () {
        final source = MarkdownSource(
          text: '''
```dart
a
```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[0]: '',
          }),
          '''
```dart
```
''',
        );
      });

      test('indented code block', () {
        final source = MarkdownSource(
          text: '''
  ```dart
  a
  ```
''',
        );

        expect(
          source.replaceEnclosedSources({
            source.dartCodeBlocks()[0]: 'b',
          }),
          '''
  ```dart
  b
  ```
''',
        );
      });
    });
  });
}
