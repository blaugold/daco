// ignore_for_file: parameter_assignments

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
// ignore: implementation_imports
import 'package:analyzer/src/generated/source.dart' as analyzer_source;
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';
import 'package:collection/collection.dart';

import 'char_codes.dart';

/// Contains the root [source] of a tree of [Source]s.
abstract class Document {
  /// The URI where [source] is stored.
  String? get uri;

  /// The root [Source] which contains all [Source]s in this document.
  Source get source;

  /// This [Document] represented as a `analyzer` [analyzer_source.Source].
  analyzer_source.Source get analyzerSource;
}

/// A source text, which can be enclosed in another [enclosingSource] and can
/// enclose other [enclosedSources].
///
/// Every source is enclosed within a [document], which is the root [Source].
abstract class Source {
  /// The text of this source.
  String get text;

  /// The [LineInfo] for this source's [text].
  LineInfo get lineInfo;

  /// The document which contains this source.
  Document get document;

  /// The source which directly contains this source.
  Source? get enclosingSource;

  /// Computes sources which are directly contained by this source.
  List<Source> enclosedSources();

  /// Translates an offset within this source [to] an offset within another
  /// [Source].
  ///
  /// If no [Source] is provided the offset is translated to the offset in the
  /// [document]'s [Source].
  ///
  /// [to] must enclose this source.
  int translateOffset(int offset, {Source? to});

  /// Returns the available number of characters for one [of] the
  /// [enclosedSources], given the [lineLength] available for the enclosing
  /// source (this).
  int availableLineLength({required Source of, required int lineLength});

  /// Returns this source's [text] where [replacements] is a mapping of
  /// [Source]s to new texts to replace them with.
  ///
  /// All the [Source]s in [replacements] must be [enclosedSources].
  String replaceEnclosedSources(Map<Source, String> replacements);
}

/// A [Source] which contains Dart code.
abstract class DartSource extends Source {
  /// Creates a new [DartSource] which is the root [Source] for all enclosed
  /// [Source]s.
  factory DartSource({required String text, String? uri}) =
      _DartSourceImpl.root;

  /// Computes the [MarkdownSource]s of documentation comments in this source.
  List<MarkdownSource> documentationComments();

  /// Computes the [AnalysisError]s of the Dart code in this source.
  List<AnalysisError> analysisErrors();
}

/// A [Source] which contains Markdown.
abstract class MarkdownSource extends Source {
  /// Creates a new [MarkdownSource] which is the root [Source] for all enclosed
  /// [Source]s.
  factory MarkdownSource({required String text, String? uri}) =
      _MarkdownSourceImpl.root;

  /// Computes the [DartSource]s of fenced code blocks in this source.
  List<DartSource> dartCodeBlocks();

  /// Returns the tags [of] one of the enclosed [dartCodeBlocks].
  List<String> codeBlockTags({required Source of});
}

class _DocumentImpl extends Document {
  _DocumentImpl({this.uri});

  @override
  late final Source source;

  @override
  final String? uri;

  @override
  late final analyzerSource = StringSource(source.text, uri);
}

abstract class _AbstractSource extends Source {
  _AbstractSource({
    required this.text,
    required Source this.enclosingSource,
    required List<int> lineStartOffsets,
  })  : document = enclosingSource.document,
        _lineStartOffsets = lineStartOffsets;

  _AbstractSource.root({required this.text, String? uri})
      : document = _DocumentImpl(uri: uri),
        enclosingSource = null,
        _lineStartOffsets = null {
    (document as _DocumentImpl).source = this;
  }

  @override
  final String text;

  @override
  final Document document;

  @override
  final Source? enclosingSource;

  late final _enclosingSources = () {
    final sources = <Source>[];
    var source = enclosingSource;
    while (source != null) {
      sources.add(source);
      source = source.enclosingSource;
    }
    return sources;
  }();

  /// The offsets to the start of each line in [text] in the [enclosingSource].
  final List<int>? _lineStartOffsets;

  /// The [LineInfo] for [text].
  @override
  late final lineInfo = _provideLineInfo();

  LineInfo _provideLineInfo() => LineInfo.fromContent(text);

  @override
  int translateOffset(int offset, {Source? to}) {
    final targetSource = to ?? document.source;

    if (targetSource == this) {
      return offset;
    }

    if (targetSource == enclosingSource) {
      final location = lineInfo.getLocation(offset);
      return _lineStartOffsets![location.lineNumber - 1] +
          (location.columnNumber - 1);
    }

    if (!_enclosingSources.contains(targetSource)) {
      throw ArgumentError.value(
        to,
        'to',
        'must be a Source which is encloses this Source',
      );
    }

    final sources = _enclosingSources
        .takeWhile((source) => source != targetSource)
        .toList()
      ..add(targetSource);
    Source from = this;

    while (sources.isNotEmpty) {
      to = sources.removeAt(0);
      offset = from.translateOffset(offset, to: to);
      from = to;
    }

    return offset;
  }
}

class _DartSourceImpl extends _AbstractSource implements DartSource {
  _DartSourceImpl({
    required super.text,
    required super.enclosingSource,
    required super.lineStartOffsets,
  });

  _DartSourceImpl.root({required super.text, super.uri}) : super.root();

  late final _parsedStringResult = parseString(
    content: text,
    path: document.uri,
    throwIfDiagnostics: false,
  );

  late final _analysisErrors =
      _parsedStringResult.errors.map(_translateAnalysisError).toList();

  late final _documentationComments = _collectDocumentationComments();

  final _documentationCommentAstNodes = <MarkdownSource, Comment>{};

  @override
  LineInfo _provideLineInfo() => _parsedStringResult.lineInfo;

  int _commentIndentation(Comment comment) =>
      lineInfo.getLocation(comment.offset).columnNumber - 1;

  @override
  List<Source> enclosedSources() => documentationComments();

  @override
  int availableLineLength({required Source of, required int lineLength}) {
    assert(of is MarkdownSource);

    if (!enclosedSources().contains(of)) {
      throw ArgumentError.value(
        of,
        'of',
        'must be a an enclosed source',
      );
    }

    const commentPrefix = 4; // '/// '
    return lineLength -
        (_commentIndentation(_documentationCommentAstNodes[of]!) +
            commentPrefix);
  }

  @override
  List<MarkdownSource> documentationComments() => _documentationComments;

  List<MarkdownSource> _collectDocumentationComments() {
    final collector = _CommentCollector();
    _parsedStringResult.unit.accept(collector);
    final comments = collector.comments;

    return comments.map((comment) {
      final lineStartOffsets = <int>[];
      final buffer = StringBuffer();

      // Each token in a comment represents a line.
      for (final token in comment.tokens) {
        // We drop the first space of each line, if it exists.
        final lineStart =
            token.lexeme.length > 3 && token.lexeme.codeUnitAt(3) == $SPACE
                ? 4
                : 3;
        buffer.writeln(token.lexeme.substring(lineStart));
        lineStartOffsets.add(token.offset + lineStart);
      }

      final source = _MarkdownSourceImpl(
        text: buffer.toString(),
        enclosingSource: this,
        lineStartOffsets: lineStartOffsets,
      );

      _documentationCommentAstNodes[source] = comment;

      return source;
    }).toList();
  }

  @override
  List<AnalysisError> analysisErrors() => _analysisErrors;

  /// Translates an [AnalysisError] to be relative to the [document]'s [Source].
  AnalysisError _translateAnalysisError(AnalysisError error) {
    if (document.source == this) {
      return error;
    }

    return AnalysisError.forValues(
      document.analyzerSource,
      translateOffset(error.offset),
      error.length,
      error.errorCode,
      error.message,
      error.correctionMessage,
    );
  }

  @override
  String replaceEnclosedSources(Map<Source, String> replacements) {
    if (replacements.isEmpty) {
      return text;
    }

    final replacementByComment = replacements.entries
        .map(
          (entry) =>
              MapEntry(_documentationCommentAstNodes[entry.key]!, entry.value),
        )
        .sortedByCompare<int>((entry) => entry.key.offset, (a, b) => a - b);

    final buffer = StringBuffer();

    Comment? lastComment;

    for (final entry in replacementByComment) {
      final comment = entry.key;
      final replacement = entry.value;

      final indentation = ' ' * _commentIndentation(comment);

      final lines = replacement.split('\n');
      if (lines.length > 1 && lines.last.isEmpty) {
        lines.removeLast();
      }

      buffer.write(text.substring(lastComment?.end ?? 0, comment.offset));

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

      lastComment = comment;
    }

    buffer.write(text.substring(lastComment!.end));

    return buffer.toString();
  }
}

class _CommentCollector extends RecursiveAstVisitor<void> {
  final List<Comment> comments = [];

  @override
  void visitComment(Comment node) {
    if (node.isDocumentation && node.beginToken.lexeme.startsWith('///')) {
      comments.add(node);
    }
  }
}

final _fencedDartCodeRegExp =
    RegExp(r'^( *)```dart([^\n]*)\n(((?!```)(.|\n))*)```', multiLine: true);

class _MarkdownSourceImpl extends _AbstractSource implements MarkdownSource {
  _MarkdownSourceImpl({
    required super.text,
    required super.enclosingSource,
    required super.lineStartOffsets,
  });

  _MarkdownSourceImpl.root({required super.text, super.uri}) : super.root();

  late final _dartCodeBlocks = _parseDartCodeBlocks();
  final _dartCodeBlockMatches = <DartSource, RegExpMatch>{};
  final _dartCodeBlockTags = <DartSource, List<String>>{};

  @override
  List<Source> enclosedSources() => dartCodeBlocks();

  @override
  int availableLineLength({required Source of, required int lineLength}) {
    assert(of is DartSource);

    if (!enclosedSources().contains(of)) {
      throw ArgumentError.value(
        of,
        'of',
        'must be a an enclosed source',
      );
    }

    final indentation = _dartCodeBlockMatches[of]!.group(1)!;
    return lineLength - indentation.length;
  }

  @override
  List<DartSource> dartCodeBlocks() => _dartCodeBlocks;

  List<DartSource> _parseDartCodeBlocks() {
    final matches = _fencedDartCodeRegExp.allMatches(text);
    final dartCodeBlocks = <DartSource>[];

    for (final match in matches) {
      final indentation = match.group(1)!.length;
      final tags = match.group(2)!;
      final code = match.group(3)!;

      // LineInfo returns one-based line numbers and since the code starts
      // on the line after the ```, we need don't need to subtract 1 from
      // `lineNumber`.
      final firstLineOfCode = lineInfo.getLocation(match.start).lineNumber;
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
          lineInfo.getOffsetOfLine(firstLineOfCode + index) + lineIndentation,
        );
      });

      final source = _DartSourceImpl(
        text: buffer.toString(),
        enclosingSource: this,
        lineStartOffsets: lineStartOffsets,
      );
      dartCodeBlocks.add(source);

      _dartCodeBlockMatches[source] = match;
      _dartCodeBlockTags[source] = _parseTags(tags);
    }

    return dartCodeBlocks;
  }

  List<String> _parseTags(String tags) => tags
      .split(' ')
      .map((tag) => tag.trim())
      .whereNot((tag) => tag.isEmpty)
      .toList();

  @override
  List<String> codeBlockTags({required Source of}) {
    if (!dartCodeBlocks().contains(of)) {
      throw ArgumentError.value(
        of,
        'of',
        'must be an enclosed Source',
      );
    }

    return _dartCodeBlockTags[of]!;
  }

  @override
  String replaceEnclosedSources(Map<Source, String> replacements) {
    if (replacements.isEmpty) {
      return text;
    }

    final replacementByMatch = replacements.entries
        .map(
          (entry) => MapEntry(_dartCodeBlockMatches[entry.key]!, entry.value),
        )
        .sortedByCompare<int>((entry) => entry.key.start, (a, b) => a - b);

    final buffer = StringBuffer();

    RegExpMatch? lastMatch;

    for (final entry in replacementByMatch) {
      final match = entry.key;
      final replacement = entry.value;

      final indentation = ' ' * match.group(1)!.length;
      final tags = match.group(2)!;

      final lines = replacement.split('\n');
      if (lines.length > 1 && lines.last.isEmpty) {
        lines.removeLast();
      }

      buffer
        ..write(text.substring(lastMatch?.end ?? 0, match.start))
        ..write(indentation)
        ..write('```dart')
        ..write(tags)
        ..writeln();

      lines.forEachIndexed((index, line) {
        if (line.isNotEmpty) {
          buffer
            ..write(indentation)
            ..writeln(line);
        } else if (index < lines.length - 1) {
          buffer.writeln();
        }
      });

      buffer
        ..write(indentation)
        ..write('```');

      lastMatch = match;
    }

    buffer.write(text.substring(lastMatch!.end));

    return buffer.toString();
  }
}
