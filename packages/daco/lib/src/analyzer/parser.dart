import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart' hide Block;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source.dart';
import 'package:collection/collection.dart';

import '../char_codes.dart';
import '../file_utils.dart';
import 'block.dart';
import 'block_impl.dart';
import 'composed_block.dart';
import 'error/analysis_error_utils.dart';
import 'exceptions.dart';

final _fencedCodeRegExp = RegExp(
  r'^(?<indent> *)([~`]{3,})(?<infoLine>.*)\n(?<code>((.|\n))*?)^\1\2',
  multiLine: true,
);

/// Parser for parsing [Block]s.
class BlockParser {
  /// Creates a parser for parsing [Block]s.
  BlockParser();

  /// The block that was parsed during the last call to [parse].
  Block? block;

  /// The errors that were discovered during the last call to [parse].
  List<AnalysisError>? errors;

  /// Parses the root [Block] for [source] and stores the result in [block] and
  /// [errors].
  void parse(Source source, {bool withErrorsInRootBlock = false}) {
    block = null;
    errors = [];

    if (isDartFile(source.fullName)) {
      _parseDartSource(source, withErrorsInRootBlock: withErrorsInRootBlock);
    } else if (isMarkdownFile(source.fullName)) {
      _parseMarkdownSource(source);
    } else {
      throw UnsupportedFileType(source.fullName);
    }
  }

  void _parseDartSource(Source source, {required bool withErrorsInRootBlock}) {
    final LineInfo lineInfo;
    final CompilationUnit astNode;
    final List<AnalysisError> errors;

    final result = parseString(
      content: source.contents.data,
      path: source.fullName,
      throwIfDiagnostics: false,
    );
    lineInfo = result.lineInfo;
    astNode = result.unit;
    errors = result.errors;

    final block = this.block = DartBlockImpl.root(
      text: source.contents.data,
      lineInfo: lineInfo,
      source: source,
    );

    if (withErrorsInRootBlock) {
      this.errors!.addAll(errors);
    }

    _parseDocumentationComments(block, astNode);
  }

  void _parseMarkdownSource(Source source) {
    final block = this.block = MarkdownBlockImpl.root(
      text: source.contents.data,
      source: source,
    );

    _parseFencedCodeBlocks(block);
  }

  void _parseDocumentationComments(
    DartBlockImpl block,
    CompilationUnit astNode, {
    int astOffset = 0,
  }) {
    final collector = _CommentCollector();
    astNode.accept(collector);

    for (final commentAstNode in collector.comments) {
      final lineStartOffsets = <int>[];
      final buffer = StringBuffer();

      // Each token in a comment represents a line.
      for (final token in commentAstNode.tokens) {
        // We drop the first space of each line, if it exists.
        final lineStart =
            token.lexeme.length > 3 && token.lexeme.codeUnitAt(3) == $SPACE
            ? 4
            : 3;
        buffer.writeln(token.lexeme.substring(lineStart));
        lineStartOffsets.add(token.offset + lineStart + astOffset);
      }

      final childBlock = MarkdownBlockImpl.child(
        text: buffer.toString(),
        lineStartOffsets: lineStartOffsets,
      );

      block.addEnclosedDocumentationComment(
        childBlock,
        Span(
          offset: commentAstNode.offset + astOffset,
          length: commentAstNode.length,
        ),
      );

      _parseFencedCodeBlocks(childBlock);
    }
  }

  void _parseFencedCodeBlocks(MarkdownBlockImpl block) {
    final matches = _fencedCodeRegExp.allMatches(block.text);

    for (final match in matches) {
      final infoLine = match.namedGroup('infoLine')!;
      final indentation = match.namedGroup('indent')!.length;
      final code = match.namedGroup('code')!;

      if (!infoLine.startsWith('dart')) {
        // Don't continue parsing fenced code blocks that don't contain Dart.
        continue;
      }

      final attributes = infoLine
          .split(RegExp(r'\s+'))
          .map((attribute) => attribute.trim())
          .toList();
      final codeBlockAttributes = _parseCodeBlockAttributes(attributes).toSet();
      final isMain = codeBlockAttributes.contains(CodeBlockAttribute.main);
      final isIgnored = codeBlockAttributes.contains(CodeBlockAttribute.ignore);

      // LineInfo returns one-based line numbers and since the code starts
      // on the line after the ```, we need don't need to subtract 1 from
      // `lineNumber`.
      final firstLineOfCode = block.lineInfo
          .getLocation(match.start)
          .lineNumber;
      final buffer = StringBuffer();
      final lineStartOffsets = <int>[];

      final lines = code.split('\n');
      lines.forEachIndexed((index, line) {
        var lineIndentation = 0;
        while (lineIndentation < indentation &&
            line.length > lineIndentation &&
            line.codeUnitAt(lineIndentation) == $SPACE) {
          lineIndentation++;
        }

        buffer.write(line.substring(lineIndentation));

        if (index < lines.length - 1) {
          buffer.writeln();
        }

        lineStartOffsets.add(
          block.lineInfo.getOffsetOfLine(firstLineOfCode + index) +
              lineIndentation,
        );
      });

      final childBlock = DartBlockImpl.child(
        text: buffer.toString(),
        attributes: attributes,
        codeBlockAttributes: codeBlockAttributes,
        lineStartOffsets: lineStartOffsets,
      );

      block.addFencedCodeBlock(
        childBlock,
        Span(
          offset: match.start + indentation,
          length: match.end - match.start - indentation,
        ),
      );

      if (!isIgnored) {
        final parseBlock = ComposedDartBlock([
          if (isMain) 'Future<void> main() async {',
          childBlock,
          if (isMain) '}',
        ]);

        final parseResult = parseString(
          content: parseBlock.text,
          throwIfDiagnostics: false,
        );

        final blockErrors = parseResult.errors
            .map((error) => truncateMultilineError(error, parseResult.lineInfo))
            .map(parseBlock.translateAnalysisError)
            .whereType<AnalysisError>();

        errors!.addAll(blockErrors);

        _parseDocumentationComments(
          childBlock,
          parseResult.unit,
          astOffset: parseBlock.blockOffset(childBlock),
        );
      }
    }

    _parseDartCodeExamples(block);
  }

  void _parseDartCodeExamples(MarkdownBlockImpl block) {
    Iterable<List<DartBlock>> codeBlockGroups() sync* {
      List<DartBlock>? parts;
      for (final codeBlock in block.dartCodeBlocks) {
        final isMultiPartBegin = codeBlock.codeBlockAttributes.contains(
          CodeBlockAttribute.multiBeing,
        );
        final isMultiPartEnd = codeBlock.codeBlockAttributes.contains(
          CodeBlockAttribute.multiEnd,
        );

        if (parts == null) {
          // We are not already in a multi-part example.
          if (isMultiPartBegin) {
            // Start a new multi-part code example.
            parts = [codeBlock];
          } else {
            // Just a single part code example.
            yield [codeBlock];
          }
        } else {
          // We are in a multi-part example.
          if (isMultiPartBegin) {
            // The user did not terminate the previous multi-part example, so we
            // do it for them.
            yield parts;
            // Start a new multi-part code example.
            parts = [codeBlock];
          } else {
            parts.add(codeBlock);

            if (isMultiPartEnd) {
              // Terminate the current multi-part example.
              yield parts;
              parts = null;
            }
          }
        }
      }

      if (parts != null) {
        // The user did not terminate the current multi-part example, so we
        // do it for them.
        yield parts;
      }
    }

    codeBlockGroups()
        .where((group) => group.any((codeBlock) => !codeBlock.isIgnored))
        .map((codeBlocks) => DartCodeExampleImpl(codeBlocks: codeBlocks))
        .forEach(block.addDartCodeExamples);
  }
}

class _CommentCollector extends RecursiveAstVisitor<void> {
  final List<Comment> comments = [];

  @override
  void visitComment(Comment node) {
    if (node.beginToken.lexeme.startsWith('///')) {
      comments.add(node);
    }
  }
}

Iterable<CodeBlockAttribute> _parseCodeBlockAttributes(
  List<String> attributes,
) sync* {
  for (final attribute in attributes) {
    switch (attribute) {
      case 'ignore':
        yield CodeBlockAttribute.ignore;
        break;
      case 'main':
        yield CodeBlockAttribute.main;
        break;
      case 'no_format':
        yield CodeBlockAttribute.noFormat;
        break;
      case 'no_analyze':
        yield CodeBlockAttribute.noAnalyze;
        break;
      case 'multi_begin':
        yield CodeBlockAttribute.multiBeing;
        break;
      case 'multi_end':
        yield CodeBlockAttribute.multiEnd;
        break;
    }
  }
}
