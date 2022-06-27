import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:daco/src/analyzer/analyzer.dart';
import 'package:daco/src/analyzer/block.dart';
import 'package:daco/src/analyzer/exceptions.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

late ContextRoot contextRoot;
late OverlayResourceProvider resourceProvider;
late DacoAnalyzer analyzer;

String writeFile(String path, String content) {
  final fullPath = sandboxFilePath(path);
  resourceProvider.setOverlay(
    fullPath,
    content: content,
    modificationStamp: 0,
  );
  return fullPath;
}

void main() {
  setUpAll(() async {
    await createSandboxDir();
  });

  setUp(() {
    resourceProvider =
        OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);

    final contextLocator = ContextLocator(resourceProvider: resourceProvider);
    contextRoot =
        contextLocator.locateRoots(includedPaths: [sandboxDir!.path]).first;

    analyzer = DacoAnalyzer(
      contextRoot: contextRoot,
      resourceProvider: resourceProvider,
    );
  });

  group('getParsedBlock', () {
    test('throws if file does not exit', () {
      expect(
        () => analyzer.getParsedBlock(sandboxFilePath('a')),
        throwsA(isA<FileDoesNotExist>()),
      );
    });

    group('Dart', () {
      test('empty file', () async {
        final path = writeFile('a.dart', '');
        final result = analyzer.getParsedBlock(path);
        expect(result.errors, isEmpty);
        expect(result.block, isA<DartBlock>());
      });
    });

    group('Markdown', () {
      test('empty  file', () async {
        final path = writeFile('a.md', '');
        final result = analyzer.getParsedBlock(path);
        expect(result.errors, isEmpty);
        expect(result.block, isA<MarkdownBlock>());
      });
    });
  });

  group('getError', () {
    test('throws if file does not exit', () {
      expect(
        () => analyzer.getErrors(sandboxFilePath('a')),
        throwsA(isA<FileDoesNotExist>()),
      );
    });

    group('Dart', () {
      test('empty file', () async {
        final path = writeFile('a.dart', '');
        expect(await analyzer.getErrors(path), isEmpty);
      });

      group('comment code block', () {
        test('ignores ignored block', () async {
          final path = writeFile(
            'a.dart',
            '''
/// ```dart ignore
/// a
/// ```
const a = 'a';
''',
          );
          final errors = await analyzer.getErrors(path);
          expect(errors, isEmpty);
        });

        test('ignores block with no_analyze attribute', () async {
          final path = writeFile(
            'a.dart',
            '''
/// ```dart no_analyze
/// const int a = 'a';
/// ```
const a = 'a';
''',
          );
          final errors = await analyzer.getErrors(path);
          expect(errors, isEmpty);
        });

        test('error in block without attributes', () async {
          final path = writeFile(
            'a.dart',
            '''
/// ```dart
/// const a = 'a'
/// ```
const a = 'a';
''',
          );
          final errors = await analyzer.getErrors(path);
          expect(errors, hasLength(1));
          expect(errors.first.offset, 26);
          expect(errors.first.length, 3);
        });

        test('error in main block', () async {
          final path = writeFile(
            'a.dart',
            '''
/// ```dart main
/// print();
/// ```
const a = 'a';
''',
          );
          final errors = await analyzer.getErrors(path);
          expect(errors, hasLength(1));
          expect(errors.first.offset, 26);
          expect(errors.first.length, 2);
          expect(
            errors.first.message,
            '1 positional argument(s) expected, but 0 found.',
          );
        });

        test('error in multi-part code example', () async {
          final path = writeFile(
            'a.dart',
            '''
/// ```dart multi_begin
/// const b = 'b';
/// ```
/// ```dart multi_end main
/// print(b);
/// print();
/// ```
const a = 'a';
''',
          );
          final errors = await analyzer.getErrors(path);
          expect(errors, hasLength(1));
          expect(errors.first.offset, 101);
          expect(errors.first.length, 2);
          expect(
            errors.first.message,
            '1 positional argument(s) expected, but 0 found.',
          );
        });
      });
    });

    group('Markdown', () {
      test('empty file', () async {
        final path = writeFile('a.md', '');
        expect(await analyzer.getErrors(path), isEmpty);
      });

      test('error in fenced code block', () async {
        final path = writeFile(
          'a.md',
          '''
```dart
const a = 'a'
```
''',
        );
        final errors = await analyzer.getErrors(path);
        expect(errors, hasLength(1));
        expect(errors.first.offset, 18);
        expect(errors.first.length, 3);
      });
    });
  });
}
