// ignore_for_file: public_member_api_docs, parameter_assignments

import 'package:analyzer/error/error.dart';
// ignore: implementation_imports
import 'package:analyzer/src/generated/source.dart';
import 'package:collection/collection.dart';

import 'block.dart';

class Span {
  Span({required this.offset, required this.length});

  final int offset;
  final int length;

  int get end => offset + length;

  bool contains(int offset) => this.offset <= offset && offset < end;
}

abstract class BlockImpl extends Block {
  BlockImpl.child({
    required this.text,
    required List<int> lineStartOffsets,
    LineInfo? lineInfo,
    List<String>? attributes,
  })  : lineInfo = lineInfo ?? LineInfo.fromContent(text),
        _source = null,
        _lineStartOffsets = lineStartOffsets,
        attributes = List.unmodifiable(attributes ?? const []);

  BlockImpl.root({
    required this.text,
    required Source source,
    LineInfo? lineInfo,
  })  : lineInfo = lineInfo ?? LineInfo.fromContent(text),
        _source = source,
        _lineStartOffsets = null,
        attributes = [] {
    enclosingBlock = null;
  }

  @override
  final String text;

  final Source? _source;

  @override
  Source get source => _source ?? rootBlock.source;

  @override
  final LineInfo lineInfo;

  /// The offsets to the start of each line in [text] in the [enclosingBlock].
  final List<int>? _lineStartOffsets;

  @override
  final List<String> attributes;

  @override
  BlockImpl get rootBlock => enclosingBlock?.rootBlock ?? this;

  @override
  late final BlockImpl? enclosingBlock;

  final _enclosedBlocks = <Block>[];
  final _enclosedBlockSpans = <Block, Span>{};

  @override
  List<Block> get enclosedBlocks => List.unmodifiable(_enclosedBlocks);

  void _addEnclosedBlock(BlockImpl block, Span span) {
    block.enclosingBlock = this;
    _enclosedBlocks.add(block);
    _enclosedBlockSpans[block] = span;
  }

  late final _enclosingBlocks = () {
    final blocks = <BlockImpl>[];
    var block = enclosingBlock;
    while (block != null) {
      blocks.add(block);
      block = block.enclosingBlock;
    }
    return blocks;
  }();

  @override
  int translateOffset(int offset, {covariant BlockImpl? to}) {
    final targetBlock = to ?? rootBlock;

    if (targetBlock == this) {
      return offset;
    }

    if (targetBlock == enclosingBlock) {
      final location = lineInfo.getLocation(offset);
      return _lineStartOffsets![location.lineNumber - 1] +
          (location.columnNumber - 1);
    }

    if (!_enclosingBlocks.contains(targetBlock)) {
      throw ArgumentError.value(
        to,
        'to',
        'must be a Block which is encloses this Block',
      );
    }

    final blocks = _enclosingBlocks
        .takeWhile((block) => block != targetBlock)
        .toList()
      ..add(targetBlock);
    var from = this;

    while (blocks.isNotEmpty) {
      to = blocks.removeAt(0);
      offset = from.translateOffset(offset, to: to);
      from = to;
    }

    return offset;
  }

  int _spanIndentation(Span span) =>
      lineInfo.getLocation(span.offset).columnNumber - 1;
}

class DartBlockImpl extends BlockImpl implements DartBlock {
  DartBlockImpl.child({
    required super.text,
    required super.lineStartOffsets,
    super.lineInfo,
    super.attributes,
    Set<CodeBlockAttribute>? codeBlockAttributes,
  })  : codeBlockAttributes = Set.unmodifiable(codeBlockAttributes ?? const {}),
        super.child();

  DartBlockImpl.root({
    required super.text,
    super.lineInfo,
    required super.source,
  })  : codeBlockAttributes = const {},
        super.root();

  @override
  final Set<CodeBlockAttribute> codeBlockAttributes;

  @override
  bool get isIgnored => codeBlockAttributes.contains(CodeBlockAttribute.ignore);

  @override
  bool get isInMainBody =>
      codeBlockAttributes.contains(CodeBlockAttribute.main);

  @override
  bool get shouldBeFormatted =>
      !isIgnored && !codeBlockAttributes.contains(CodeBlockAttribute.noFormat);

  @override
  List<MarkdownBlock> get documentationComments => enclosedBlocks.cast();

  void addEnclosedDocumentationComment(
    MarkdownBlockImpl block,
    Span commentSpan,
  ) {
    _addEnclosedBlock(block, commentSpan);
  }

  @override
  AnalysisError translateAnalysisError(
    AnalysisError error, {
    int errorOffset = 0,
  }) {
    // Translate an [AnalysisError] to be relative to the [source].

    if (rootBlock == this) {
      return error;
    }

    return AnalysisError.forValues(
      source,
      translateOffset(error.offset + errorOffset),
      error.length,
      error.errorCode,
      error.message,
      error.correctionMessage,
    );
  }

  @override
  int availableLineLength({required Block of, required int lineLength}) {
    assert(of is MarkdownBlock);

    if (!enclosedBlocks.contains(of)) {
      throw ArgumentError.value(
        of,
        'of',
        'must be an enclosed Block',
      );
    }

    const commentPrefix = 4; // '/// '
    return lineLength -
        (_spanIndentation(_enclosedBlockSpans[of]!) + commentPrefix);
  }

  @override
  String replaceEnclosedBlocks(Map<Block, String> replacements) {
    if (replacements.isEmpty) {
      return text;
    }

    final replacementByComment = replacements.entries
        .map((entry) => MapEntry(_enclosedBlockSpans[entry.key]!, entry.value))
        .sortedByCompare<int>((entry) => entry.key.offset, (a, b) => a - b);

    final buffer = StringBuffer();

    Span? lastCommentSpan;

    for (final entry in replacementByComment) {
      final comment = entry.key;
      final replacement = entry.value;

      final indentation = ' ' * _spanIndentation(comment);

      final lines = replacement.split('\n');
      if (lines.length > 1 && lines.last.isEmpty) {
        lines.removeLast();
      }

      buffer.write(text.substring(lastCommentSpan?.end ?? 0, comment.offset));

      lines.forEachIndexed((index, line) {
        if (index != 0) {
          buffer.write(indentation);
        }

        buffer.write('///');

        if (line.isNotEmpty) {
          buffer
            ..write(' ')
            ..write(line);
        }

        if (index < lines.length - 1) {
          buffer.writeln();
        }
      });

      lastCommentSpan = comment;
    }

    buffer.write(text.substring(lastCommentSpan!.end));

    return buffer.toString();
  }
}

class MarkdownBlockImpl extends BlockImpl implements MarkdownBlock {
  MarkdownBlockImpl.child({
    required super.text,
    required super.lineStartOffsets,
    super.lineInfo,
    super.attributes,
  }) : super.child();

  MarkdownBlockImpl.root({
    required super.text,
    super.lineInfo,
    required super.source,
  }) : super.root();

  @override
  List<DartBlock> get dartCodeBlocks => enclosedBlocks.cast();

  void addFencedCodeBlock(DartBlockImpl block, Span fencedCodeBlockSpan) {
    _addEnclosedBlock(block, fencedCodeBlockSpan);
  }

  @override
  int availableLineLength({required Block of, required int lineLength}) {
    assert(of is DartBlock);

    if (!enclosedBlocks.contains(of)) {
      throw ArgumentError.value(
        of,
        'of',
        'must be an enclosed Block',
      );
    }

    return lineLength - _spanIndentation(_enclosedBlockSpans[of]!);
  }

  @override
  String replaceEnclosedBlocks(Map<Block, String> replacements) {
    if (replacements.isEmpty) {
      return text;
    }

    final replacementBySpan = replacements.entries
        .map((entry) => MapEntry(_enclosedBlockSpans[entry.key]!, entry.value))
        .sortedByCompare<int>((entry) => entry.key.offset, (a, b) => a - b);

    final buffer = StringBuffer();

    Span? lastFencedCodeBlockSpan;

    for (final entry in replacementBySpan) {
      final span = entry.key;
      final replacement = entry.value;

      final indentation = ' ' * _spanIndentation(span);

      final lines = replacement.split('\n');
      if (lines.length > 1 && lines.last.isEmpty) {
        lines.removeLast();
      }

      // Write the text preceding the fenced code block and the line introducing
      // the fenced code block.
      buffer.write(
        text.substring(
          lastFencedCodeBlockSpan?.end ?? 0,
          lineInfo.getOffsetOfLineAfter(span.offset),
        ),
      );

      // Write the new content of the fenced code block.
      lines.forEachIndexed((index, line) {
        if (line.isNotEmpty) {
          buffer
            ..write(indentation)
            ..writeln(line);
        } else if (index < lines.length - 1) {
          buffer.writeln();
        }
      });

      // Write the line ending the fenced code block.
      buffer.write(
        text.substring(
          lineInfo.getOffsetOfLine(
            lineInfo.getLocation(span.end - 1).lineNumber - 1,
          ),
          span.end,
        ),
      );

      lastFencedCodeBlockSpan = span;
    }

    buffer.write(text.substring(lastFencedCodeBlockSpan!.end));

    return buffer.toString();
  }
}
