import 'package:analyzer/src/string_source.dart';
import 'package:daco/src/analyzer/parser.dart';
import 'package:test/test.dart';

void main() {
  test('complex example', () {
    final source = StringSource(
      '''
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
''',
      'test.dart',
    );

    final parser = BlockParser()..parse(source);

    expect(parser.errors, isEmpty);
    expect(parser.block?.enclosedBlocks, hasLength(1));
    expect(parser.block?.enclosedBlocks.first.enclosedBlocks, hasLength(3));
    expect(
      parser.block?.enclosedBlocks.first.enclosedBlocks[2].enclosedBlocks,
      hasLength(1),
    );
  });
}
