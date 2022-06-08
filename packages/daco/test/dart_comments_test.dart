import 'package:daco/src/dart_comments.dart';
import 'package:test/test.dart';

void main() {
  group('processComments', () {
    test('supports empty file', () async {
      final result = processComments(
        path: 'a',
        source: '',
        processor: expectAsync2(noopFormatter, count: 0),
      );
      expect(await result, '');
    });

    test('supports file without comments', () async {
      final result = processComments(
        path: 'a',
        source: "const a = 'a';",
        processor: expectAsync2(noopFormatter, count: 0),
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
        processor: expectAsync2((comment, lineLength) {
          expect(comment, 'A\n');
          expect(lineLength, 80 - 4);
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
        processor: expectAsync2((comment, lineLength) {
          expect(comment, 'A\nB\n');
          expect(lineLength, 80 - 4);
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
        processor: expectAsync2(count: 2, (comment, lineLength) {
          expect(comment, anyOf(['A\n', 'B\n']));
          expect(lineLength, 80 - 4);
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
        processor: expectAsync2((comment, lineLength) {
          expect(comment, 'A\n');
          expect(lineLength, 80 - 6);
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
        processor: expectAsync2((comment, lineLength) {
          expect(comment, 'A\nB\n');
          expect(lineLength, 80 - 6);
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

String noopFormatter(String comment, int lineLength) => comment;

String testFormatter(String comment, int lineLength) => 'Test $comment';
