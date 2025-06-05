import 'package:analyzer/src/string_source.dart';
import 'package:daco/src/analyzer/parser.dart';
import 'package:test/test.dart';

import '../test_utils/parse_utils.dart';

void main() {
  group('Dart', () {
    group('documentation comments', () {
      test('empty', () {
        final block = parseDart('');
        expect(block.enclosedBlocks, isEmpty);
        expect(block.documentationComments, isEmpty);
      });

      test('no comments', () {
        final block = parseDart('''
const a = 'a';
''');
        expect(block.enclosedBlocks, isEmpty);
        expect(block.documentationComments, isEmpty);
      });

      test('single comment', () {
        final block = parseDart('''
/// A
const a = 'a';
''');

        final comments = block.documentationComments;
        expect(comments, block.enclosedBlocks);
        expect(comments, hasLength(1));
        expect(comments.first.text, 'A\n');
      });

      test('multiple comments', () {
        final block = parseDart('''
/// A
const a = 'a';

/// B
const b = 'b';
''');

        final comments = block.documentationComments;
        expect(comments, block.enclosedBlocks);
        expect(comments, hasLength(2));
        expect(comments[0].text, 'A\n');
        expect(comments[1].text, 'B\n');
      });

      test('multi-line comments', () {
        final block = parseDart('''
/// A
/// B
const a = 'a';
''');

        final comment = block.documentationComments.first;
        expect(comment.text, 'A\nB\n');
        expect(comment.translateOffset(0), 4);
        expect(comment.translateOffset(2), 10);
      });

      test('strips the first space of each line if it exists', () {
        final block = parseDart('''
/// A
///B
const a = 'a';
''');

        final comment = block.documentationComments.first;
        expect(comment.text, 'A\nB\n');
        expect(comment.translateOffset(0), 4);
        expect(comment.translateOffset(2), 9);
      });

      test('indented comments', () {
        final block = parseDart('''
  /// A
  /// B
const a = 'a';
''');

        final comment = block.documentationComments.first;
        expect(comment.text, 'A\nB\n');
        expect(comment.translateOffset(0), 6);
        expect(comment.translateOffset(2), 14);
      });
    });

    group('analysis errors', () {
      test('in root source', () {
        final result = parseDartWithErrors('''
const a = 'a'
''');

        final analysisErrors = result.errors;
        expect(analysisErrors, hasLength(1));
        expect(analysisErrors.first.source.contents.data, result.block.text);
        expect(analysisErrors.first.offset, 10);
        expect(analysisErrors.first.length, 3);
        expect(analysisErrors.first.message, "Expected to find ';'.");
      });

      test('in enclosed source', () {
        final result = parseMarkdownWithErrors('''
```dart
const a = 'a'
```
''');

        final analysisErrors = result.errors;
        expect(analysisErrors, hasLength(1));
        expect(analysisErrors.first.source.contents.data, result.block.text);
        expect(analysisErrors.first.offset, 18);
        expect(analysisErrors.first.length, 3);
        expect(analysisErrors.first.message, "Expected to find ';'.");
      });
    });

    test('advanced comment', () {
      final source = StringSource('''
/// A
///
/// ```dart
/// const b = 'b';
/// ```
///
/// ```dart main
/// print('Hello');
/// ```
///
/// ```dart
/// /// C
/// const c = 'c';
/// ```
const a = 'a';
''', 'test.dart');

      final parser = BlockParser()..parse(source);

      expect(parser.errors, isEmpty);
      expect(parser.block?.enclosedBlocks, hasLength(1));
      expect(parser.block?.enclosedBlocks.first.enclosedBlocks, hasLength(3));
      expect(
        parser.block?.enclosedBlocks.first.enclosedBlocks[2].enclosedBlocks,
        hasLength(1),
      );
    });
  });

  group('Markdown', () {
    group('fenced Dart code blocks', () {
      test('empty', () {
        final block = parseMarkdown('');
        expect(block.enclosedBlocks, isEmpty);
        expect(block.dartCodeBlocks, isEmpty);
      });

      test('no code blocks', () {
        final block = parseMarkdown('''
A
''');
        expect(block.enclosedBlocks, isEmpty);
        expect(block.dartCodeBlocks, isEmpty);
      });

      test('single code block', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
```
''');

        final codeBlocks = block.dartCodeBlocks;
        expect(codeBlocks, block.enclosedBlocks);
        expect(codeBlocks, hasLength(1));
        expect(codeBlocks.first.text, 'a\n');
      });

      test('multi line code blocks', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
```
```dart
b
```
''');

        final codeBlocks = block.dartCodeBlocks;
        expect(codeBlocks, block.enclosedBlocks);
        expect(codeBlocks, hasLength(2));
        expect(codeBlocks[0].text, 'a\n');
        expect(codeBlocks[1].text, 'b\n');
      });

      test('multiple code blocks', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
b
```
''');

        final codeBlock = block.dartCodeBlocks.first;
        expect(codeBlock.text, 'a\nb\n');
        expect(codeBlock.translateOffset(0), 8);
        expect(codeBlock.translateOffset(2), 10);
      });

      test('indented code blocks', () {
        final block = parseMarkdown(allowErrors: true, '''
  ```dart
  a
  b
  ```
''');

        final codeBlock = block.dartCodeBlocks.first;
        expect(codeBlock.text, 'a\nb\n');
        expect(codeBlock.translateOffset(0), 12);
        expect(codeBlock.translateOffset(2), 16);
      });
    });

    group('Dart code examples', () {
      test('single code block', () {
        final block = parseMarkdown('''
```dart
const a = 'a';
```
''');

        expect(block.dartCodeExamples, hasLength(1));
        expect(block.dartCodeExamples.first.codeBlocks, block.dartCodeBlocks);
      });

      test('multiple single code blocks', () {
        final block = parseMarkdown('''
```dart
const a = 'a';
```
```dart
const b = 'b';
```
''');

        expect(block.dartCodeExamples, hasLength(2));
        expect(block.dartCodeExamples[0].codeBlocks, [block.dartCodeBlocks[0]]);
        expect(block.dartCodeExamples[1].codeBlocks, [block.dartCodeBlocks[1]]);
      });

      test('multi-part', () {
        final block = parseMarkdown('''
```dart multi_begin
const a = 'a';
```
```dart multi_end
const b = 'b';
```
''');

        expect(block.dartCodeExamples, hasLength(1));
        expect(block.dartCodeExamples[0].codeBlocks, block.dartCodeBlocks);
      });

      test('multiple multi-part', () {
        final block = parseMarkdown('''
```dart multi_begin
const a = 'a';
```
```dart multi_end
const b = 'b';
```
```dart multi_begin
const c = 'c';
```
```dart multi_end
const d = 'd';
```
''');

        expect(block.dartCodeExamples, hasLength(2));
        expect(
          block.dartCodeExamples[0].codeBlocks,
          block.dartCodeBlocks.sublist(0, 2),
        );
        expect(
          block.dartCodeExamples[1].codeBlocks,
          block.dartCodeBlocks.sublist(2),
        );
      });

      test('single code block and multi-part', () {
        final block = parseMarkdown('''
```dart
const a = 'a';
```
```dart multi_begin
const b = 'b';
```
```dart multi_end
const c = 'c';
```
''');

        expect(block.dartCodeExamples, hasLength(2));
        expect(
          block.dartCodeExamples[0].codeBlocks,
          block.dartCodeBlocks.sublist(0, 1),
        );
        expect(
          block.dartCodeExamples[1].codeBlocks,
          block.dartCodeBlocks.sublist(1),
        );
      });

      test('skip if code block is ignored', () {
        final block = parseMarkdown('''
```dart ignore
const a = 'a';
```
''');

        expect(block.dartCodeExamples, isEmpty);
      });

      test('skip if all code blocks in multi-part are ignored', () {
        final block = parseMarkdown('''
```dart multi_begin ignore
const a = 'a';
```
```dart multi_end ignore
const b = 'b';
```
''');

        expect(block.dartCodeExamples, isEmpty);
      });

      test('keep partially ignored multi-part', () {
        final block = parseMarkdown('''
```dart multi_begin
const a = 'a';
```
```dart multi_end ignore
const b = 'b';
```
''');

        expect(block.dartCodeExamples, hasLength(1));
      });
    });
  });
}
