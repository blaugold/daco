import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Resolves the Dart language version of Dart files from the package
/// configuration of the package that contains them, like `dart format` does.
class LanguageVersionResolver {
  final _packageConfigs = <String, Future<PackageConfig?>>{};

  /// Returns the language version of the package that contains [file], or
  /// `null` if it cannot be determined.
  Future<Version?> languageVersionOf(File file) async {
    final absolutePath = p.normalize(file.absolute.path);
    final PackageConfig? packageConfig;
    try {
      packageConfig = await _packageConfigFor(p.dirname(absolutePath));
    } on Object {
      return null;
    }
    final languageVersion = packageConfig
        ?.packageOf(p.toUri(absolutePath))
        ?.languageVersion;
    if (languageVersion == null) {
      return null;
    }
    return Version(languageVersion.major, languageVersion.minor, 0);
  }

  Future<PackageConfig?> _packageConfigFor(String directory) => _packageConfigs
      .putIfAbsent(directory, () => findPackageConfig(Directory(directory)));
}
