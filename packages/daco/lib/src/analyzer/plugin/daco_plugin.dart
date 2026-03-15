import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'daco_rule.dart';

/// Analyzer plugin that integrates daco with the analysis server.
class DacoPlugin extends Plugin {
  @override
  String get name => 'daco';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(DacoRule());
  }
}
