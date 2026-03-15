import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/utilities.dart' as analyzer_utilities;
import 'package:analyzer/dart/ast/ast.dart' hide Block;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';

import '../../file_utils.dart';
import '../block.dart';
import '../parser.dart';

/// Analysis rule that checks Dart code examples in documentation comments.
class DacoRule extends MultiAnalysisRule {
  /// Creates a new [DacoRule].
  DacoRule()
    : super(
        name: 'daco_code_example',
        description:
            'Checks Dart code examples in documentation comments for errors.',
      );

  /// Diagnostic code for errors discovered in Dart code examples within
  /// documentation comments.
  static const codeExampleDiagnostic = LintCode(
    'daco_code_example',
    '{0}',
    uniqueName: 'daco_code_example',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<DiagnosticCode> get diagnosticCodes => [codeExampleDiagnostic];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final DacoRule rule;
  final RuleContext context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final currentUnit = context.currentUnit;
    if (currentUnit == null) {
      return;
    }

    final path = currentUnit.file.path;
    if (!isDartFile(path)) {
      return;
    }

    final content = currentUnit.content;
    final parser = BlockParser();

    try {
      parser.parse(StringSource(content, path));
    } on Object {
      // If parsing fails, skip analysis for this file.
      return;
    }

    final block = parser.block;
    final parsingErrors = parser.errors;

    if (block == null || parsingErrors == null) {
      return;
    }

    // Report parsing errors from daco's parser.
    for (final error in parsingErrors) {
      rule.reportAtOffset(
        error.offset,
        error.length,
        diagnosticCode: DacoRule.codeExampleDiagnostic,
        arguments: [error.message],
      );
    }

    // Find code examples and check them for syntax errors.
    if (block is! DartBlock) {
      return;
    }

    block.documentationComments
        .expand((comment) => comment.dartCodeExamples)
        .where((example) => example.shouldBeAnalyzed)
        .forEach(_checkCodeExample);
  }

  void _checkCodeExample(DartCodeExample example) {
    final composedLibrary = example.buildExampleLibrary();

    final parseResult = analyzer_utilities.parseString(
      content: composedLibrary.text,
      throwIfDiagnostics: false,
    );

    for (final error in parseResult.errors) {
      final translated = composedLibrary.translateAnalysisError(error);
      if (translated == null) {
        // Error is in synthesized code, not the user's code example.
        continue;
      }

      rule.reportAtOffset(
        translated.offset,
        translated.length,
        diagnosticCode: DacoRule.codeExampleDiagnostic,
        arguments: [translated.message],
      );
    }
  }
}
