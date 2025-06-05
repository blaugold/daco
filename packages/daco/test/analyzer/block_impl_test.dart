import 'package:test/test.dart';

import '../test_utils/parse_utils.dart';

void main() {
  group('DartBlock', () {
    group('replace enclosed blocks', () {
      test('nothing', () {
        const text = '''
const a = 'a';
''';
        final block = parseDart(text);

        expect(block.replaceEnclosedBlocks({}), text);
      });

      test('single comment', () {
        final block = parseDart('''
/// A
const a = 'a';
''');

        expect(
          block.replaceEnclosedBlocks({block.documentationComments.first: 'B'}),
          '''
/// B
const a = 'a';
''',
        );
      });

      test('multiple comments', () {
        final block = parseDart('''
/// A
const a = 'a';

/// B
const b = 'b';
''');

        expect(
          block.replaceEnclosedBlocks({
            block.documentationComments[0]: 'C',
            block.documentationComments[1]: 'D',
          }),
          '''
/// C
const a = 'a';

/// D
const b = 'b';
''',
        );
      });

      test('one of multiple comments', () {
        final block = parseDart('''
/// A
const a = 'a';

/// B
const b = 'b';
''');

        expect(
          block.replaceEnclosedBlocks({block.documentationComments[0]: 'C'}),
          '''
/// C
const a = 'a';

/// B
const b = 'b';
''',
        );

        expect(
          block.replaceEnclosedBlocks({block.documentationComments[1]: 'D'}),
          '''
/// A
const a = 'a';

/// D
const b = 'b';
''',
        );
      });

      test('multi line comments', () {
        final block = parseDart('''
/// A
/// B
const a = 'a';
''');

        expect(
          block.replaceEnclosedBlocks({block.documentationComments.first: 'C'}),
          '''
/// C
const a = 'a';
''',
        );

        expect(
          block.replaceEnclosedBlocks({
            block.documentationComments.first: 'C\nD',
          }),
          '''
/// C
/// D
const a = 'a';
''',
        );
      });

      test('trims last empty line', () {
        final block = parseDart('''
/// A
const a = 'a';
''');

        expect(
          block.replaceEnclosedBlocks({
            block.documentationComments.first: 'B\n',
          }),
          '''
/// B
const a = 'a';
''',
        );
      });

      test('empty replacement', () {
        final block = parseDart('''
/// A
const a = 'a';
''');

        expect(
          block.replaceEnclosedBlocks({block.documentationComments.first: ''}),
          '''
///
const a = 'a';
''',
        );
      });

      test('indented comment', () {
        final block = parseDart('''
  /// A
const a = 'a';
''');

        expect(
          block.replaceEnclosedBlocks({block.documentationComments.first: 'B'}),
          '''
  /// B
const a = 'a';
''',
        );
      });
    });
  });

  group('MarkdownBlock', () {
    group('replace enclosed sources', () {
      test('nothing', () {
        const text = '''
A
''';
        final block = parseMarkdown(text);

        expect(block.replaceEnclosedBlocks({}), text);
      });

      test('single code block', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
```
''');

        expect(
          block.replaceEnclosedBlocks({block.dartCodeBlocks.first: 'b'}),
          '''
```dart
b
```
''',
        );
      });

      test('multiple code blocks', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
```
```dart
b
```
''');

        expect(
          block.replaceEnclosedBlocks({
            block.dartCodeBlocks[0]: 'c',
            block.dartCodeBlocks[1]: 'd',
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
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
```
```dart
b
```
''');

        expect(block.replaceEnclosedBlocks({block.dartCodeBlocks[0]: 'c'}), '''
```dart
c
```
```dart
b
```
''');

        expect(block.replaceEnclosedBlocks({block.dartCodeBlocks[1]: 'c'}), '''
```dart
a
```
```dart
c
```
''');
      });

      test('multi-line code blocks', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
b
```
''');

        expect(block.replaceEnclosedBlocks({block.dartCodeBlocks[0]: 'c'}), '''
```dart
c
```
''');

        expect(
          block.replaceEnclosedBlocks({block.dartCodeBlocks[0]: 'c\nd'}),
          '''
```dart
c
d
```
''',
        );
      });

      test('trim last empty line', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
```
''');

        expect(
          block.replaceEnclosedBlocks({block.dartCodeBlocks[0]: 'b\n'}),
          '''
```dart
b
```
''',
        );
      });

      test('empty replacement', () {
        final block = parseMarkdown(allowErrors: true, '''
```dart
a
```
''');

        expect(block.replaceEnclosedBlocks({block.dartCodeBlocks[0]: ''}), '''
```dart
```
''');
      });

      test('indented code block', () {
        final block = parseMarkdown(allowErrors: true, '''
  ```dart
  a
  ```
''');

        expect(block.replaceEnclosedBlocks({block.dartCodeBlocks[0]: 'b'}), '''
  ```dart
  b
  ```
''');
      });
    });
  });
}
