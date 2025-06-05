import 'package:daco/src/command_runner.dart';
import 'package:daco/src/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  setUp(() async {
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
${p.relative(file.path)}:2:15 • Expected to find ';'. • EXPECTED_TOKEN
''');
  });
}
