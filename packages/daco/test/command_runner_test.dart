import 'dart:io';

import 'package:daco/src/command_runner.dart';
import 'package:test/test.dart';

void main() {
  test('smoke test', () async {
    final tmpDir = Directory.systemTemp.createTempSync('daco');

    final file = File('${tmpDir.path}/test.dart')
      ..writeAsStringSync(
        '''
/// a  a
const a = 'a';
''',
      );

    await DacoCommandRunner().run(['format', file.path]);

    expect(
      file.readAsStringSync(),
      '''
/// a a
const a = 'a';
''',
    );
  });
}
