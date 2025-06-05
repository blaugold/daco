import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/byte_store.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/file_byte_store.dart';
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:solvent/solvent.dart';

import '../utils.dart';
import 'analysis_context.dart';
import 'analysis_session.dart';
import 'block.dart';
import 'composed_block.dart';
import 'error/analysis_error_utils.dart';
import 'exceptions.dart';
import 'parser.dart';
import 'result.dart';
import 'result_impl.dart';

final _homePath = Platform.isWindows
    ? Platform.environment['USERPROFILE']!
    : Platform.environment['HOME']!;

final _byteStorePath = p.join(_homePath, '.dartServer', '.daco');

/// Creates the [ByteStore] that is used by daco.
ByteStore createByteStore() {
  Directory(_byteStorePath).createSync(recursive: true);
  return FileByteStore(_byteStorePath);
}

/// Creates an [AnalysisContextCollection] for use by an [DacoAnalyzer].
AnalysisContextCollection createAnalysisContextCollection({
  required List<String> includedPaths,
  ResourceProvider? resourceProvider,
}) => AnalysisContextCollectionImpl(
  includedPaths: includedPaths,
  byteStore: createByteStore(),
  resourceProvider: resourceProvider is OverlayResourceProvider
      ? resourceProvider
      : OverlayResourceProvider(PhysicalResourceProvider.INSTANCE),
);

/// Implementation of [DacoAnalysisContext] and [DacoAnalysisSession] for
/// analysis of files in a [contextRoot].
class DacoAnalyzer implements DacoAnalysisContext, DacoAnalysisSession {
  /// Creates a new [DacoAnalyzer] for analysis of files in the given
  /// [contextRoot].
  DacoAnalyzer({required AnalysisContext analysisContext})
    : _context = analysisContext,
      _resourceProvider =
          analysisContext.contextRoot.resourceProvider
              as OverlayResourceProvider,
      contextRoot = analysisContext.contextRoot;

  final AnalysisContext _context;

  final OverlayResourceProvider _resourceProvider;

  @override
  final ContextRoot contextRoot;

  @override
  DacoAnalysisSession get session => this;

  @override
  late final Pubspec? pubspec = _loadPubspec();

  late final _publicApiFileUri = _resolvePublicApiFileUri();

  final _parser = BlockParser();

  Pubspec? _loadPubspec() {
    final pubspecFile = _resourceProvider.getFile(
      p.join(contextRoot.root.path, 'pubspec.yaml'),
    );
    return pubspecFile.exists
        ? Pubspec.parse(pubspecFile.readAsStringSync())
        : null;
  }

  Uri? _resolvePublicApiFileUri() {
    final publicApiFileUri = pubspec?.let(
      (it) => Uri.parse('package:${it.name}/${it.name}.dart'),
    );

    final publicApiFile = publicApiFileUri
        ?.let(_context.currentSession.uriConverter.uriToPath)
        ?.let(_resourceProvider.getFile);

    if (publicApiFile?.exists ?? false) {
      return publicApiFileUri;
    }

    return null;
  }

  @override
  Future<List<AnalysisError>> getErrors(String path) async {
    final result = await _computeAnalysisResult(path);

    // We use a set to avoid duplicating errors when combining different
    // sources.
    final allErrors = <AnalysisError>{...result.parsedBlockResult.errors};

    for (final codeExampleResult in result.codeExampleResults) {
      allErrors.addAll(
        codeExampleResult.resolvedUnitResult.errors
            .map(
              (error) => truncateMultilineError(
                error,
                codeExampleResult.resolvedUnitResult.lineInfo,
              ),
            )
            .map(codeExampleResult.composedLibrary.translateAnalysisError)
            .whereType(),
      );
    }

    return allErrors.toList();
  }

  @override
  ParsedBlockResult getParsedBlock(String path) {
    final file = _resourceProvider.getFile(path);

    if (!file.exists) {
      throw FileDoesNotExist(path);
    }

    final text = file.readAsStringSync();
    _parser.parse(StringSource(text, path));
    return ParsedBlockResultImpl(_parser.block!, _parser.errors!, this);
  }

  Future<_FileResult> _computeAnalysisResult(String path) async {
    if (!_resourceProvider.getFile(path).exists) {
      throw FileDoesNotExist(path);
    }

    final parsedBlockResult = getParsedBlock(path);
    final block = parsedBlockResult.block;

    Iterable<DartCodeExample> codeExamples;
    if (block is DartBlock) {
      codeExamples = block.documentationComments.expand(
        (comment) => comment.dartCodeExamples,
      );
    } else if (block is MarkdownBlock) {
      codeExamples = block.dartCodeExamples;
    } else {
      unreachable();
    }

    codeExamples = codeExamples.where((example) => example.shouldBeAnalyzed);

    final codeExampleResults = await Future.wait(
      codeExamples.mapIndexed((index, example) async {
        final now = DateTime.now().millisecondsSinceEpoch;

        final codeExamplePath = p.join(
          p.dirname(path),
          '${p.basenameWithoutExtension(path)}_$index.dart',
        );
        final composedLibrary = example.buildExampleLibrary(
          publicApiFileUri: _publicApiFileUri,
          uri: codeExamplePath,
        );

        _resourceProvider.setOverlay(
          codeExamplePath,
          content: composedLibrary.text,
          modificationStamp: now,
        );

        _context.changeFile(codeExamplePath);
        await _context.applyPendingFileChanges();

        final result = await _context.currentSession.getResolvedUnit(
          codeExamplePath,
        );

        if (result is! ResolvedUnitResult) {
          throw Exception('$result for $codeExamplePath');
        }

        return _CodeExampleResult(
          example: example,
          composedLibrary: composedLibrary,
          resolvedUnitResult: result,
        );
      }),
    );

    return _FileResult(
      path: path,
      parsedBlockResult: parsedBlockResult,
      codeExampleResults: codeExampleResults,
    );
  }
}

class _FileResult {
  _FileResult({
    required this.path,
    required this.parsedBlockResult,
    required this.codeExampleResults,
  });

  final String path;
  final ParsedBlockResult parsedBlockResult;
  final List<_CodeExampleResult> codeExampleResults;
}

class _CodeExampleResult {
  _CodeExampleResult({
    required this.example,
    required this.composedLibrary,
    required this.resolvedUnitResult,
  });

  final DartCodeExample example;
  final ComposedDartBlock composedLibrary;
  final ResolvedUnitResult resolvedUnitResult;
}

extension on DartCodeExample {
  ComposedDartBlock buildExampleLibrary({Uri? publicApiFileUri, String? uri}) {
    final parts = <Object>[
      if (publicApiFileUri != null) ...[
        '// ignore: UNUSED_IMPORT',
        'import "$publicApiFileUri";',
        '',
      ],
    ];

    final nonMainBlocks = codeBlocks
        .where((block) => !block.isIgnored && !block.isInMainBody)
        .toList();
    final mainBlocks = codeBlocks
        .where((block) => !block.isIgnored && block.isInMainBody)
        .toList();

    for (final block in nonMainBlocks) {
      parts
        ..add(block)
        ..add('');
    }

    if (mainBlocks.isNotEmpty) {
      parts
        ..add('Future<void> main() async {')
        ..addAll(mainBlocks)
        ..add('}');
    }

    return ComposedDartBlock(parts, uri: uri);
  }
}
