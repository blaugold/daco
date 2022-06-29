import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

final dacoPubspecFile = File('packages/daco/pubspec.yaml');
final analyzerPluginPubspecFile =
    File('packages/daco/tools/analyzer_plugin/pubspec.yaml');

void main() {
  final dacoPubspec = loadYaml(dacoPubspecFile.readAsStringSync()) as YamlMap;
  final dacoVersion = dacoPubspec['version'] as String;

  _updateAnalyzerPlugin(dacoVersion);
}

/// Updates the dependency on `daco` in the analyzer plugin to have the same
/// version as the `daco` package itself.
void _updateAnalyzerPlugin(String dacoVersion) {
  final editor = YamlEditor(analyzerPluginPubspecFile.readAsStringSync())
    ..update(['dependencies', 'daco'], dacoVersion);
  analyzerPluginPubspecFile.writeAsStringSync(editor.toString());
}
