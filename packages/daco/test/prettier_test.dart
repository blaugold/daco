// ignore_for_file: avoid_catches_without_on_clauses, avoid_print

import 'package:daco/src/logging.dart';
import 'package:daco/src/prettier.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('server handles many concurrent requests', () async {
    final logger = TestLogger(isVerbose: true);
    final service = PrettierService(logger: logger.toDacoLogger());
    await service.start();
    addTearDown(service.stop);

    try {
      await Future.wait(
        Iterable.generate(
          1000,
          (i) => service.format(
            '$i',
            parser: 'markdown',
            printWidth: 80,
            proseWrap: ProseWrap.always,
          ),
        ),
      ).timeout(const Duration(minutes: 1));
    } catch (e) {
      print(logger.output);
      rethrow;
    }
  });
}
