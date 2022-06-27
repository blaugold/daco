import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/context_builder.dart';
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
import 'exceptions.dart';
import 'parser.dart';
import 'result.dart';
import 'result_impl.dart';

final _homePath = Platform.isWindows
    ? Platform.environment['USERPROFILE']!
    : Platform.environment['HOME']!;

final _byteStorePath = p.join(_homePath, '.dartServer', '.daco');

/// Implementation of [DacoAnalysisContext] and [DacoAnalysisSession] for
/// analysis of files in a [contextRoot].
class DacoAnalyzer implements DacoAnalysisContext, DacoAnalysisSession {
  /// Creates a new [DacoAnalyzer] for analysis of files in the given
  /// [contextRoot].
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
    Directory(_byteStorePath).createSync(recursive: true);
    final fileByteStore = FileByteStore(_byteStorePath);

    final contextBuilder =
        ContextBuilderImpl(resourceProvider: _resourceProvider);

    return contextBuilder.createContext(
      contextRoot: contextRoot,
      byteStore: fileByteStore,
    );
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
  ParsedBlockResult getParsedBlock(String path) {
    final file = _resourceProvider.getFile(path);

    if (!file.exists) {
      throw FileDoesNotExist(path);
    }

    final text = file.readAsStringSync();
    _parser.parse(StringSource(text, path));
    return ParsedBlockResultImpl(_parser.block!, _parser.errors!, this);
  }

  @override
  Future<List<AnalysisError>> getErrors(String path) async {
    if (!_resourceProvider.getFile(path).exists) {
      throw FileDoesNotExist(path);
    }

    final result = getParsedBlock(path);
    final block = result.block;

    Iterable<DartCodeExample> dartCodeExamples;
    if (block is DartBlock) {
      dartCodeExamples = block.documentationComments
          .expand((comment) => comment.dartCodeExamples);
    } else if (block is MarkdownBlock) {
      dartCodeExamples = block.dartCodeExamples;
    } else {
      unreachable();
    }

    dartCodeExamples =
        dartCodeExamples.where((example) => example.shouldBeAnalyzed);

    // We use a set to avoid duplicating errors when combining different
    // sources.
    final allErrors = <AnalysisError>{...result.errors};

    await Future.wait(
      dartCodeExamples.mapIndexed((index, example) async {
        final codeExamplePath = p.join(
          p.dirname(path),
          '${p.basenameWithoutExtension(path)}_$index.dart',
        );
        final codeExampleLibrary = example.buildExampleLibrary(
          publicApiFileUri: _publicApiFileUri,
          uri: codeExamplePath,
        );

        _resourceProvider.setOverlay(
          codeExamplePath,
          content: codeExampleLibrary.text,
          modificationStamp: 0,
        );

        final result = await _context.currentSession.getErrors(codeExamplePath);

        if (result is! ErrorsResult) {
          throw Exception('$result for $codeExamplePath');
        }

        final errors = result.errors
            .map(codeExampleLibrary.translateAnalysisError)
            .toList();

        allErrors.addAll(errors);
      }),
    );

    return allErrors.toList();
  }
}

extension on DartCodeExample {
  ComposedDartBlock buildExampleLibrary({
    Uri? publicApiFileUri,
    String? uri,
  }) {
    final parts = <Object>[
      if (publicApiFileUri != null) ...[
        '// ignore: UNUSED_IMPORT',
        'import "$publicApiFileUri";',
        ''
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
