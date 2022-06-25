// ignore_for_file: public_member_api_docs

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:solvent/solvent.dart';

import 'analysis_context.dart';
import 'analysis_session.dart';
import 'block.dart';
import 'composed_dart_unit.dart';
import 'parser.dart';
import 'result.dart';
import 'result_impl.dart';

class DacoAnalyzer implements DacoAnalysisContext, DacoAnalysisSession {
  DacoAnalyzer({
    required this.contextRoot,
    ResourceProvider? resourceProvider,
  }) : _resourceProvider = OverlayResourceProvider(
          resourceProvider ?? PhysicalResourceProvider.INSTANCE,
        );

  @override
  final ContextRoot contextRoot;

  @override
  DacoAnalysisSession get session => this;

  @override
  late final Pubspec? pubspec = _loadPubspec();

  late final _publicApiFileUri = _resolvePublicApiFileUri();

  final OverlayResourceProvider _resourceProvider;

  late final _context = _buildContext();

  late final _parser = BlockParser(analysisContext: _context);

  AnalysisContext _buildContext() {
    final contextBuilder = ContextBuilder(resourceProvider: _resourceProvider);
    return contextBuilder.createContext(contextRoot: contextRoot);
  }

  Pubspec? _loadPubspec() {
    final pubspecFile = _resourceProvider
        .getFile(p.join(contextRoot.root.path, 'pubspec.yaml'));
    return pubspecFile.exists
        ? Pubspec.parse(pubspecFile.readAsStringSync())
        : null;
  }

  Uri? _resolvePublicApiFileUri() {
    final publicApiFileUri =
        pubspec?.let((it) => Uri.parse('package:${it.name}/${it.name}.dart'));

    final publicApiFile = publicApiFileUri
        ?.let(_context.currentSession.uriConverter.uriToPath)
        ?.let(_resourceProvider.getFile);

    if (publicApiFile?.exists ?? false) {
      return publicApiFileUri;
    }

    return null;
  }

  @override
  Future<List<AnalysisError>> getErrors(String file) async {
    // TODO handle non existent file
    // TODO cache results
    final result = getParsedBlock(file);
    // TODO handle markdown files
    final block = result.block as DartBlock;

    final exampleCodeBlocks = block.documentationComments
        .expand((comment) => comment.dartCodeBlocks)
        .whereNot((codeBlock) => codeBlock.isIgnored);

    final allErrors = <AnalysisError>[];

    await Future.wait(
      exampleCodeBlocks.mapIndexed((index, codeBlock) async {
        final analysisSourcePath = p.join(
          p.dirname(file),
          '${p.basenameWithoutExtension(file)}_$index.dart',
        );
        final analysisSource = ComposedDartUnit(
          [
            if (_publicApiFileUri != null) ...[
              '// ignore: type=lint',
              'import "$_publicApiFileUri";'
            ],
            if (codeBlock.isInMainBody) 'Future<void> main() async {',
            codeBlock,
            if (codeBlock.isInMainBody) '}',
          ],
          uri: analysisSourcePath,
        );

        _resourceProvider.setOverlay(
          analysisSourcePath,
          content: analysisSource.text,
          modificationStamp: 0,
        );

        final result =
            await _context.currentSession.getErrors(analysisSourcePath);

        if (result is! ErrorsResult) {
          throw Exception('$result for $analysisSourcePath');
        }

        final errors =
            result.errors.map(analysisSource.translateAnalysisError).toList();

        allErrors.addAll(errors);
      }),
    );

    return allErrors;
  }

  @override
  ParsedBlockResult getParsedBlock(String file) {
    // TODO handle non existent file
    // TODO cache results
    final text = _resourceProvider.getFile(file).readAsStringSync();
    _parser.parse(StringSource(text, file));
    return ParsedBlockResultImpl(_parser.block!, _parser.errors!, this);
  }
}
