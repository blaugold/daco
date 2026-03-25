import 'dart:convert';
import 'dart:io';

import 'package:daco/src/command_runner.dart';
import 'package:daco/src/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  setUp(() async {
    exitCode = 0;
    await createSandboxDir();
  });

  test('analyze Dart file in directory', () async {
    // File with error.
    final file = await writeFile('a.dart', '''
/// ```dart
/// const a = 'a'
/// ```
const a = 'a';
''');

    // File without errors.
    await writeFile('b.dart', '''
const b = 'b';
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['analyze', sandboxDir!.path]);

    expect(logger.output, '''
Analyzing ${p.relative(sandboxDir!.path)}...
${p.relative(file.path)}:2:15 • Expected to find ';'. • expected_token
''');
  });

  test('analyze markdown file', () async {
    final file = await writeFile('README.md', '''
```dart
const a = 'a'
```
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['analyze', file.path]);

    expect(
      logger.output,
      contains("${p.relative(file.path)}:2:11 • Expected to find ';'."),
    );
  });

  test('analyze mdx file', () async {
    final file = await writeFile('docs/example.mdx', '''
<CodeExample id={1} title="Hello">
```dart
const a = 'a'
```
</CodeExample>
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['analyze', file.path]);

    expect(
      logger.output,
      contains("${p.relative(file.path)}:3:11 • Expected to find ';'."),
    );
  });

  test('analyze snippet style mdx file without ambient identifiers', () async {
    final file = await writeFile('docs/example.mdx', '''
<CodeExample id={1} title="Hello">
```dart
if (data == null) {
  return;
}

await collection.saveDocument(doc);
```
</CodeExample>
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['analyze', file.path]);

    expect(exitCode, 1);
    expect(logger.output, contains('undefined_identifier'));
  });

  test('analyze supported files in directory', () async {
    final dartFile = await writeFile('lib/a.dart', '''
/// ```dart
/// const a = 'a'
/// ```
const a = 'a';
''');
    final markdownFile = await writeFile('docs/README.md', '''
```dart
const b = 'b'
```
''');
    final mdxFile = await writeFile('docs/example.mdx', '''
<CodeExample id={1} title="Hello">
```dart
const c = 'c'
```
</CodeExample>
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['analyze', sandboxDir!.path]);

    expect(
      logger.output,
      contains("${p.relative(markdownFile.path)}:2:11 • Expected to find ';'."),
    );
    expect(
      logger.output,
      contains("${p.relative(mdxFile.path)}:3:11 • Expected to find ';'."),
    );
    expect(
      logger.output,
      contains("${p.relative(dartFile.path)}:2:15 • Expected to find ';'."),
    );
  });

  test('analyze workspace docs with package override', () async {
    await writeFile('pubspec.yaml', '''
name: workspace
environment:
  sdk: ^3.10.0
''');
    await writeFile('lib/workspace.dart', '');
    await writeFile('packages/cbl/pubspec.yaml', '''
name: cbl
environment:
  sdk: ^3.10.0
''');
    await writeFile('packages/cbl/lib/cbl.dart', '''
class Database {}
''');
    final docsFile = await writeFile('docs/example.mdx', '''
<CodeExample id={1} title="Hello">
```dart main
final database = Database();
```
</CodeExample>
''');
    await _writePackageConfig(
      sandboxDir!.path,
      packages: [
        _PackageConfigEntry(
          name: 'workspace',
          rootUri: '../',
          packageUri: 'lib/',
        ),
        _PackageConfigEntry(
          name: 'cbl',
          rootUri: '../packages/cbl',
          packageUri: 'lib/',
        ),
      ],
    );

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['analyze', '--package', 'cbl', docsFile.path]);

    expect(logger.output, isNot(contains('Undefined')));
    expect(logger.output, isNot(contains('undefined_class')));
  });

  test('fails when package override cannot be resolved', () async {
    final file = await writeFile('docs/example.mdx', '''
```dart
const a = 'a';
```
''');

    final logger = TestLogger();
    await DacoCommandRunner(
      logger: logger.toDacoLogger(),
    ).run(['analyze', '--package', 'missing', file.path]);

    expect(
      logger.output,
      contains('Could not resolve package:missing/missing.dart.'),
    );
  });
}

Future<void> _writePackageConfig(
  String rootPath, {
  required List<_PackageConfigEntry> packages,
}) async {
  final file = await File(
    p.join(rootPath, '.dart_tool', 'package_config.json'),
  ).create(recursive: true);
  await file.writeAsString(
    jsonEncode({
      'configVersion': 2,
      'packages': packages
          .map(
            (package) => {
              'name': package.name,
              'rootUri': package.rootUri,
              'packageUri': package.packageUri,
              'languageVersion': '3.10',
            },
          )
          .toList(),
    }),
  );
}

class _PackageConfigEntry {
  _PackageConfigEntry({
    required this.name,
    required this.rootUri,
    required this.packageUri,
  });

  final String name;
  final String rootUri;
  final String packageUri;
}
