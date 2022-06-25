import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:solvent/solvent.dart';

import 'code_block_attribute.dart';
import 'source.dart';

/// Equivalent of an [AnalysisContext] for the purpose of analyzing comments
/// in Dart code.
abstract class DacoAnalysisContext {
  /// Creates a new [DacoAnalysisContext] for analysis of the body of code
  /// in the given [contextRoot].
  factory DacoAnalysisContext({
    required ContextRoot contextRoot,
    ResourceProvider? resourceProvider,
  }) = _DacoAnalysisContextImpl;

  /// The [ContextRoot] which contains the code analyzed by this instance.
  ContextRoot get contextRoot;

  /// The [DacoAnalysisSession] that provides the results of analyzing code
  /// in [contextRoot].
  DacoAnalysisSession get session;
}

/// Equivalent of an [AnalysisSession] for the purpose of analyzing comments
/// in Dart code.
abstract class DacoAnalysisSession {
  /// The parsed contents of the pubspec.yaml file in the [ContextRoot] this
  /// session is analyzing, if the file exists.
  Pubspec? get pubspec;

  /// Returns [AnalysisError]s for code blocks within documentation comments
  /// of all Dart files.
  ///
  /// Errors are grouped by the absolute path to the file which contains the
  /// errors.
  Future<Map<String, List<AnalysisError>>> allErrors();

  /// Returns all [AnalysisError]s for code blocks within documentation comments
  /// of the given [file]
  Future<List<AnalysisError>> errorsForFile(String file);
}

class _DacoAnalysisContextImpl implements DacoAnalysisContext {
  _DacoAnalysisContextImpl({
    required this.contextRoot,
    ResourceProvider? resourceProvider,
  }) : session = _DacoAnalysisSessionImpl(
          contextRoot: contextRoot,
          resourceProvider: OverlayResourceProvider(
            resourceProvider ?? PhysicalResourceProvider.INSTANCE,
          ),
        );

  @override
  final ContextRoot contextRoot;

  @override
  final DacoAnalysisSession session;
}

class _DacoAnalysisSessionImpl implements DacoAnalysisSession {
  _DacoAnalysisSessionImpl({
    required this.contextRoot,
    required this.resourceProvider,
  });

  final ContextRoot contextRoot;

  @override
  Pubspec? get pubspec => _loadPubspec();

  final OverlayResourceProvider resourceProvider;

  late final AnalysisContext _context = _buildContext();

  AnalysisSession get _session => _context.currentSession;

  late final Uri? _publicApiFileUri = _resolvePublicApiFileUri();

  AnalysisContext _buildContext() {
    final contextBuilder = ContextBuilder(resourceProvider: resourceProvider);
    return contextBuilder.createContext(contextRoot: contextRoot);
  }

  Pubspec? _loadPubspec() {
    final pubspecFile =
        resourceProvider.getFile(p.join(contextRoot.root.path, 'pubspec.yaml'));
    return pubspecFile.exists
        ? Pubspec.parse(pubspecFile.readAsStringSync())
        : null;
  }

  Uri? _resolvePublicApiFileUri() {
    final publicApiFileUri =
        pubspec?.let((it) => Uri.parse('package:${it.name}/${it.name}.dart'));

    final publicApiFile = publicApiFileUri
        ?.let(_session.uriConverter.uriToPath)
        ?.let(resourceProvider.getFile);

    if (publicApiFile?.exists ?? false) {
      return publicApiFileUri;
    }

    return null;
  }

  @override
  Future<Map<String, List<AnalysisError>>> allErrors() async {
    final allErrors = <String, List<AnalysisError>>{};

    for (final file in contextRoot.analyzedFiles()) {
      if (p.extension(file) != '.dart') {
        continue;
      }

      final fileErrors = await errorsForFile(file);
      if (fileErrors.isNotEmpty) {
        allErrors[file] = fileErrors;
      }
    }

    return allErrors;
  }

  @override
  Future<List<AnalysisError>> errorsForFile(String file) async {
    await _session.getResolvedUnit(file);

    final source = DartSource(
      text: resourceProvider.getFile(file).readAsStringSync(),
      uri: file,
    );

    final exampleCodeBlocks = source
        .documentationComments()
        .expand((comment) => comment.dartCodeBlocks())
        .whereNot((codeBlock) => codeBlock.isIgnored);

    final allErrors = <AnalysisError>[];

    await Future.wait(
      exampleCodeBlocks.mapIndexed((index, codeBlock) async {
        final analysisSourcePath = p.join(
          p.dirname(file),
          '${p.basenameWithoutExtension(file)}_$index.dart',
        );
        final analysisSource = DartSource.composed(
          [
            if (_publicApiFileUri != null) ...[
              '// ignore: type=lint',
              'import "$_publicApiFileUri";'
            ],
            if (codeBlock.isInMainFunction) 'Future<void> main() async {',
            codeBlock,
            if (codeBlock.isInMainFunction) '}',
          ],
          uri: analysisSourcePath,
        );

        resourceProvider.setOverlay(
          analysisSourcePath,
          content: analysisSource.text,
          modificationStamp: 0,
        );

        final result = await _session.getErrors(analysisSourcePath);

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
}
