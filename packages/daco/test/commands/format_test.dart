import 'dart:convert';

import 'package:daco/src/command_runner.dart';
import 'package:daco/src/logging.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:term_glyph/term_glyph.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  setUp(() async {
    ascii = false;
    await createSandboxDir();
    await installPrettierServer();
  });

  test('format file', () async {
    final file = await writeFile('test.dart', '''
/// a  a
const a = 'a';
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['format', file.path]);

    expect(file.readAsStringSync(), '''
/// a a
const a = 'a';
''');

    expect(logger.output, '''
CHANGED   ${p.relative(file.path)}
''');
  });

  test('formatting of dart file fails', () async {
    final file = await writeFile('test.dart', '''
const a = 'a'
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['format', file.path]);

    expect(logger.output, '''
FAILED    ${p.relative(file.path)}
Could not format because the source could not be parsed:

line 1, column 11 of ${p.prettyUri(file.path)}: Expected to find ';'.
  ╷
1 │ const a = 'a'
  │           ^^^
  ╵
''');
  });

  test('formatting of fenced code block fails', () async {
    final file = await writeFile('test.dart', '''
/// ```dart
/// const a = 'a'
/// ```
const a = 'a';
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['format', file.path]);

    expect(logger.output, '''
FAILED    ${p.relative(file.path)}
Could not format because the source could not be parsed:

line 2, column 15 of ${p.prettyUri(file.path)}: Expected to find ';'.
  ╷
2 │ /// const a = 'a'
  │               ^^^
  ╵
''');
  });

  group('language version', () {
    // A declaration whose formatting differs between the short and the tall
    // style.
    const declaration =
        'typedef SaveHandler = Future<bool> Function(Object document, '
        'Object? conflictingDocument, int attempt);';
    const source =
        '$declaration\n'
        '\n'
        '/// ```dart\n'
        '/// $declaration\n'
        '/// ```\n'
        'const a = 1;\n';

    String expectedOutput(Version languageVersion) {
      String format({int pageWidth = 80}) => DartFormatter(
        languageVersion: languageVersion,
        pageWidth: pageWidth,
      ).format('$declaration\n').trimRight();

      return [
        format(),
        '',
        '/// ```dart',
        ...format(pageWidth: 76).split('\n').map((line) => '/// $line'),
        '/// ```',
        'const a = 1;',
        '',
      ].join('\n');
    }

    Future<void> writePackageConfig(String languageVersion) async {
      await writeFile(
        '.dart_tool/package_config.json',
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'sandbox',
              'rootUri': '../',
              'packageUri': 'lib/',
              'languageVersion': languageVersion,
            },
          ],
        }),
      );
    }

    test('uses language version of package', () async {
      await writePackageConfig('2.19');
      final file = await writeFile('lib/test.dart', source);

      await DacoCommandRunner(
        logger: TestLogger().toDacoLogger(),
      ).run(['format', file.path]);

      expect(file.readAsStringSync(), expectedOutput(Version(2, 19, 0)));
    });

    test('uses latest language version without package config', () async {
      final file = await writeFile('lib/test.dart', source);

      await DacoCommandRunner(
        logger: TestLogger().toDacoLogger(),
      ).run(['format', file.path]);

      expect(
        file.readAsStringSync(),
        expectedOutput(DartFormatter.latestLanguageVersion),
      );
    });
  });
}
