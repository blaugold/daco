// ignore_for_file: public_member_api_docs

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:collection/collection.dart';

import 'block.dart';
import 'block_impl.dart';
import 'composed_block.dart';

final _directiveLineRegExp = RegExp(
  r'^\s*(import|export|part(?!\s+of\b)|library)\b',
);
final _annotationLineRegExp = RegExp(r'^\s*@');
final _declarationStartRegExp = RegExp(
  r'^\s*(abstract\s+class|base\s+class|final\s+class|interface\s+class|sealed\s+class|class|mixin|enum|extension|typedef)\b',
);
final _functionDeclarationLineRegExp = RegExp(
  r'^\s*(external\s+)?[\w<>\[\]?., ]+\s+\w+\s*\([^;]*\)\s*(async\*?|sync\*?)?\s*(=>|{)\s*$',
);
final _mainBodyIndicatorRegExp = RegExp(
  r'\bawait\b|^\s*(if|for|while|switch|try|return|throw|break|continue)\b',
  multiLine: true,
);

class DartBlockComposition {
  DartBlockComposition({
    required this.topLevelBlocks,
    required this.mainBodyBlocks,
  });

  final List<DartBlock> topLevelBlocks;
  final List<DartBlock> mainBodyBlocks;

  bool get isMixed => topLevelBlocks.isNotEmpty && mainBodyBlocks.isNotEmpty;
}

extension DartBlockCompose on DartCodeExample {
  ComposedDartBlock buildExampleLibrary({
    Uri? publicApiFileUri,
    Map<String, String> ambientDeclarations = const {},
    String? uri,
  }) {
    final topLevelBlocks = <DartBlock>[];
    final mainBlocks = <DartBlock>[];

    for (final block in codeBlocks.where((it) => !it.isIgnored)) {
      final composition = composeDartBlock(block);
      topLevelBlocks.addAll(composition.topLevelBlocks);
      mainBlocks.addAll(composition.mainBodyBlocks);
    }

    final existingImports = topLevelBlocks.map((it) => it.text).join('\n');
    final shouldAddPublicApiImport =
        publicApiFileUri != null &&
        !existingImports.contains('import "$publicApiFileUri";');

    final parts = <Object>[
      if (shouldAddPublicApiImport) ...[
        '// ignore: UNUSED_IMPORT',
        'import "$publicApiFileUri";',
        '',
      ],
    ];

    for (final block in topLevelBlocks) {
      parts
        ..add(block)
        ..add('');
    }

    if (ambientDeclarations.isNotEmpty) {
      parts
        ..add(r'T _$dacoAmbient<T>() => throw UnimplementedError();')
        ..add('');
      for (final entry in ambientDeclarations.entries.sortedBy(
        (it) => it.key,
      )) {
        parts
          ..add(_buildAmbientDeclaration(entry.key, entry.value))
          ..add('');
      }
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

DartBlockComposition composeDartBlock(DartBlock block) {
  if (block.isIgnored) {
    return DartBlockComposition(topLevelBlocks: [], mainBodyBlocks: []);
  }

  if (block is! DartBlockImpl) {
    return block.isInMainBody
        ? DartBlockComposition(topLevelBlocks: [], mainBodyBlocks: [block])
        : DartBlockComposition(topLevelBlocks: [block], mainBodyBlocks: []);
  }

  final lineCount = block.text.split('\n').length;
  if (lineCount <= 1) {
    return _composeWholeBlock(block);
  }

  final splitLine = _findTopLevelPrefixEndLine(block.text);
  if (splitLine != null) {
    if (splitLine >= lineCount) {
      return DartBlockComposition(topLevelBlocks: [block], mainBodyBlocks: []);
    }

    if (splitLine > 0) {
      return DartBlockComposition(
        topLevelBlocks: [block.sliceLines(0, splitLine, inMainBody: false)],
        mainBodyBlocks: [
          block.sliceLines(splitLine, lineCount, inMainBody: true),
        ],
      );
    }
  }

  return _composeWholeBlock(block);
}

DartBlockComposition _composeWholeBlock(DartBlockImpl block) {
  final shouldUseMainBody =
      block.isInMainBody ||
      _mainBodyIndicatorRegExp.hasMatch(block.text) ||
      _shouldInferWholeMainBody(block);

  if (shouldUseMainBody) {
    return DartBlockComposition(
      topLevelBlocks: [],
      mainBodyBlocks: [
        if (block.isInMainBody)
          block
        else
          block.sliceLines(0, block.text.split('\n').length, inMainBody: true),
      ],
    );
  }

  return DartBlockComposition(topLevelBlocks: [block], mainBodyBlocks: []);
}

bool _shouldInferWholeMainBody(DartBlock block) {
  final plainErrors = parseString(
    content: block.text,
    throwIfDiagnostics: false,
  ).errors;
  final wrappedErrors = parseString(
    content: 'Future<void> main() async {\n${block.text}\n}',
    throwIfDiagnostics: false,
  ).errors;
  return plainErrors.length > wrappedErrors.length;
}

int? _findTopLevelPrefixEndLine(String text) {
  final lines = text.split('\n');
  var index = 0;
  var consumedAny = false;

  while (index < lines.length) {
    final nextIndex = _consumeTopLevelSection(lines, index);
    if (nextIndex == null) {
      break;
    }
    consumedAny = true;
    index = nextIndex;
  }

  if (!consumedAny) {
    return null;
  }

  while (index < lines.length && lines[index].trim().isEmpty) {
    index++;
  }

  return index;
}

int? _consumeTopLevelSection(List<String> lines, int start) {
  var index = start;
  while (index < lines.length && lines[index].trim().isEmpty) {
    index++;
  }

  if (index >= lines.length) {
    return null;
  }

  final line = lines[index];
  if (_directiveLineRegExp.hasMatch(line)) {
    return _consumeStatement(lines, index);
  }

  if (_annotationLineRegExp.hasMatch(line)) {
    final declarationIndex = _nextNonEmptyLine(lines, index + 1);
    if (declarationIndex == null ||
        !_startsTopLevelDeclaration(lines[declarationIndex])) {
      return null;
    }
    return _consumeDeclaration(lines, index);
  }

  if (_startsTopLevelDeclaration(line)) {
    return _consumeDeclaration(lines, index);
  }

  return null;
}

bool _startsTopLevelDeclaration(String line) =>
    _declarationStartRegExp.hasMatch(line) ||
    _functionDeclarationLineRegExp.hasMatch(line);

int? _nextNonEmptyLine(List<String> lines, int start) {
  for (var index = start; index < lines.length; index++) {
    if (lines[index].trim().isNotEmpty) {
      return index;
    }
  }
  return null;
}

int _consumeStatement(List<String> lines, int start) {
  var braceDepth = 0;
  var parenDepth = 0;
  for (var index = start; index < lines.length; index++) {
    final line = lines[index];
    braceDepth += '{'.allMatches(line).length - '}'.allMatches(line).length;
    parenDepth += '('.allMatches(line).length - ')'.allMatches(line).length;
    if (braceDepth <= 0 && parenDepth <= 0 && line.trimRight().endsWith(';')) {
      return index + 1;
    }
  }
  return lines.length;
}

int _consumeDeclaration(List<String> lines, int start) {
  var braceDepth = 0;
  var sawOpeningBrace = false;

  for (var index = start; index < lines.length; index++) {
    final line = lines[index];
    final openCount = '{'.allMatches(line).length;
    final closeCount = '}'.allMatches(line).length;
    if (openCount > 0) {
      sawOpeningBrace = true;
    }
    braceDepth += openCount - closeCount;

    if (!sawOpeningBrace &&
        (line.trimRight().endsWith(';') || line.trimRight().endsWith('=>'))) {
      return index + 1;
    }

    if (sawOpeningBrace && braceDepth <= 0) {
      return index + 1;
    }
  }

  return lines.length;
}

String _buildAmbientDeclaration(String identifier, String type) =>
    'final $type $identifier = _\$dacoAmbient<$type>();';
