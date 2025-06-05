import 'package:daco/src/command_runner.dart';
import 'package:daco/src/logging.dart';
import 'package:path/path.dart' as p;
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
}
