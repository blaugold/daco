import 'package:daco/src/analyzer/block.dart';
import 'package:daco/src/analyzer/utils.dart';
import 'package:test/test.dart';

void main() {
  group('parseString', () {
    test('parse Dart', () {
      final result = parseString(text: '', uri: 'text.dart');
      expect(result.block, isA<DartBlock>());
      expect(result.errors, isEmpty);
    });

    test('parse Markdown', () {
      final result = parseString(text: '', uri: 'text.md');
      expect(result.block, isA<MarkdownBlock>());
      expect(result.errors, isEmpty);
    });
  });
}
