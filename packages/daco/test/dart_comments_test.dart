import 'package:daco/src/dart_comments.dart';
import 'package:test/test.dart';

void main() {
  group('processComments', () {
    test('supports empty file', () async {
      final result = processComments(
        path: 'a',
        source: '',
        processor: expectAsync3(noopFormatter, count: 0),
      );
      expect(await result, '');
    });

    test('supports file without comments', () async {
      final result = processComments(
        path: 'a',
        source: "const a = 'a';",
        processor: expectAsync3(noopFormatter, count: 0),
      );
      expect(await result, "const a = 'a';");
    });

    test('supports single line comment', () async {
      final result = processComments(
        path: 'a',
        source: '''
/// A
const a = 'a';
''',
        processor: expectAsync3((comment, lineLength, lineOffsets) {
          expect(comment, 'A\n');
          expect(lineLength, 80 - 4);
          expect(lineOffsets, [4]);
          return comment;
        }),
      );
      expect(
        await result,
        '''
/// A
const a = 'a';
''',
      );
    });

    test('supports multi line comment', () async {
      final result = processComments(
        path: 'a',
        source: '''
/// A
/// B
const a = 'a';
''',
        processor: expectAsync3((comment, lineLength, lineOffsets) {
          expect(comment, 'A\nB\n');
          expect(lineLength, 80 - 4);
          expect(lineOffsets, [4, 10]);
          return comment;
        }),
      );
      expect(
        await result,
        '''
/// A
/// B
const a = 'a';
''',
      );
    });

    test('supports multiple comments', () async {
      final result = processComments(
        path: 'a',
        source: '''
/// A
const a = 'a';

/// B
const a = 'a';
''',
        processor: expectAsync3(count: 2, (comment, lineLength, lineOffsets) {
          expect(comment, anyOf(['A\n', 'B\n']));
          expect(lineLength, 80 - 4);
          expect(
            lineOffsets,
            anyOf([
              [4],
              [26]
            ]),
          );
          return comment;
        }),
      );
      expect(
        await result,
        '''
/// A
const a = 'a';

/// B
const a = 'a';
''',
      );
    });

    test('supports indented comment', () async {
      final result = processComments(
        path: 'a',
        source: '''
class A {
  /// A
  static const a = 'a';
}
''',
        processor: expectAsync3((comment, lineLength, lineOffsets) {
          expect(comment, 'A\n');
          expect(lineLength, 80 - 6);
          expect(lineOffsets, [16]);
          return comment;
        }),
      );
      expect(
        await result,
        '''
class A {
  /// A
  static const a = 'a';
}
''',
      );
    });

    test('supports indented multi line comment', () async {
      final result = processComments(
        path: 'a',
        source: '''
class A {
  /// A
  /// B
  static const a = 'a';
}
''',
        processor: expectAsync3((comment, lineLength, lineOffsets) {
          expect(comment, 'A\nB\n');
          expect(lineLength, 80 - 6);
          expect(lineOffsets, [16, 24]);

          return comment;
        }),
      );
      expect(
        await result,
        '''
class A {
  /// A
  /// B
  static const a = 'a';
}
''',
      );
    });
  });
}

String noopFormatter(String comment, int lineLength, List<int> lineOffsets) =>
    comment;
