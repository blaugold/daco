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

  /// Creates a new [DartSource] which compose out of lines of text and other
  /// [DartSource]s.
  ///
  /// [parts] must contain only [String]s and [DartSource]s, which are
  /// concatenated into the [text] of the resulting [DartSource]. Each [String]
  /// represents a line of text.
  factory DartSource.composed(Iterable<Object> parts, {String? uri}) =
      _ComposedDartSourceImpl;

  /// Computes the [MarkdownSource]s of documentation comments in this source.
  List<MarkdownSource> documentationComments();

  /// Computes the [AnalysisError]s of the Dart code in this source.
  List<AnalysisError> analysisErrors();

  /// Translates an [AnalysisError] that originated in this source's [text] to
  /// the correct location.
  AnalysisError translateAnalysisError(AnalysisError error);
}

/// A [Source] which contains Markdown.
abstract class MarkdownSource extends Source {
  /// Creates a new [MarkdownSource] which is the root [Source] for all enclosed
  /// [Source]s.
  factory MarkdownSource({required String text, String? uri}) =
      _MarkdownSourceImpl.root;

  /// Computes the [DartSource]s of fenced code blocks in this source.
  List<DartSource> dartCodeBlocks();

  /// Returns the info line [of] one of the enclosed [dartCodeBlocks].
  String infoLine({required Source of});
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

  late final _parseResult = parseString(
    content: text,
    path: document.uri,
    throwIfDiagnostics: false,
  );

  late final _analysisErrors =
      _parseResult.errors.map(translateAnalysisError).toList();

  late final _documentationComments = _collectDocumentationComments();

  final _documentationCommentAstNodes = <MarkdownSource, Comment>{};

  @override
  LineInfo _provideLineInfo() => _parseResult.lineInfo;

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

  /// Whether a [comment] is a documentation comment that belongs to this source
  ///
  /// Otherwise the [comment] must belong to one of its [enclosedSources].
  bool _isOwnDocumentationComment(Comment comment) => true;

  List<MarkdownSource> _collectDocumentationComments() {
    final collector = _CommentCollector();
    _parseResult.unit.accept(collector);
    final comments = collector.comments;

    return comments.where(_isOwnDocumentationComment).map((comment) {
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

  @override
  AnalysisError translateAnalysisError(AnalysisError error) {
    // Translate an [AnalysisError] to be relative to the [document]'s
    // [Source].

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

class _ComposedDartSourceImpl extends _DartSourceImpl {
  factory _ComposedDartSourceImpl(Iterable<Object> parts, {String? uri}) {
    final dartSources = <_Span, DartSource>{};
    final text = _joinParts(parts, dartSources);
    return _ComposedDartSourceImpl._(
      text: text,
      uri: uri,
      dartSources: dartSources,
    );
  }

  _ComposedDartSourceImpl._({
    required super.text,
    super.uri,
    required Map<_Span, DartSource> dartSources,
  })  : _dartSources = dartSources,
        super.root();

  final Map<_Span, DartSource> _dartSources;

  late final _combinedEnclosedSource = [
    ..._dartSources.values.toList(),
    ...documentationComments(),
  ];

  static String _joinParts(
    Iterable<Object> parts,
    Map<_Span, DartSource> enclosedSources,
  ) {
    final buffer = StringBuffer();
    var offset = 0;

    for (final part in parts) {
      final String text;
      if (part is String) {
        text = part;
      } else if (part is DartSource) {
        text = part.text;
      } else {
        throw ArgumentError.value(
          part,
          'parts',
          'must contain only Strings or DartSources',
        );
      }

      if (part is DartSource) {
        enclosedSources[_Span(offset, text.length)] = part;
      }

      if (text.trimRight().endsWith('\n')) {
        buffer.write(text);
        offset += text.length;
      } else {
        buffer.writeln(text);
        offset += text.length + 1;
      }
    }

    return buffer.toString();
  }

  @override
  int availableLineLength({required Source of, required int lineLength}) {
    if (of is DartSource) {
      if (!_dartSources.values.contains(of)) {
        throw ArgumentError.value(
          of,
          'of',
          'must be a Source that is enclosed by this source',
        );
      }

      // Since we don't indent DartSources they have the full line length
      // available.
      return lineLength;
    }

    return super.availableLineLength(of: of, lineLength: lineLength);
  }

  @override
  List<Source> enclosedSources() => _combinedEnclosedSource;

  @override
  String replaceEnclosedSources(Map<Source, String> replacements) =>
      throw UnimplementedError();

  @override
  bool _isOwnDocumentationComment(Comment comment) =>
      _dartSources.keys.none((span) => span.contains(comment.offset));

  @override
  AnalysisError translateAnalysisError(AnalysisError error) {
    // Translates error to be relative to the [Document] of the
    // composed [DartSource] where the error occurred.

    final entry = _findDartSourceByOffset(error.offset);
    if (entry == null) {
      // The error occurred in the code that was added around the DartSources,
      // which we attribute to this source.
      return error;
    }

    final span = entry.key;
    final source = entry.value;

    return AnalysisError.forValues(
      source.document.analyzerSource,
      source.translateOffset(error.offset - span.offset),
      error.length,
      error.errorCode,
      error.message,
      error.correctionMessage,
    );
  }

  MapEntry<_Span, DartSource>? _findDartSourceByOffset(int offset) =>
      _dartSources.entries
          .firstWhereOrNull((entry) => entry.key.contains(offset));
}

class _Span {
  _Span(this.offset, this.length);

  final int offset;
  final int length;

  int get end => offset + length;

  bool contains(int offset) => this.offset <= offset && offset < end;
}

final _fencedCodeRegExp = RegExp(
  r'^(?<indent> *)([~`]{3,})(?<infoLine>.*)\n(?<code>((.|\n))*?)^\1\2',
  multiLine: true,
);

class _MarkdownSourceImpl extends _AbstractSource implements MarkdownSource {
  _MarkdownSourceImpl({
    required super.text,
    required super.enclosingSource,
    required super.lineStartOffsets,
  });

  _MarkdownSourceImpl.root({required super.text, super.uri}) : super.root();

  late final _dartCodeBlocks = _parseDartCodeBlocks();
  final _dartCodeBlockMatches = <DartSource, RegExpMatch>{};
  final _dartCodeBlockInfoLine = <DartSource, String>{};

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

    final indentation = _dartCodeBlockMatches[of]!.namedGroup('indent')!;
    return lineLength - indentation.length;
  }

  @override
  List<DartSource> dartCodeBlocks() => _dartCodeBlocks;

  List<DartSource> _parseDartCodeBlocks() {
    final matches = _fencedCodeRegExp.allMatches(text);
    final dartCodeBlocks = <DartSource>[];

    for (final match in matches) {
      final indentation = match.namedGroup('indent')!.length;
      final infoLine = match.namedGroup('infoLine')!;
      if (!infoLine.startsWith('dart')) {
        continue;
      }
      final code = match.namedGroup('code')!;

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
      _dartCodeBlockInfoLine[source] = infoLine;
    }

    return dartCodeBlocks;
  }

  @override
  String infoLine({required Source of}) {
    if (!dartCodeBlocks().contains(of)) {
      throw ArgumentError.value(
        of,
        'of',
        'must be an enclosed Source',
      );
    }

    return _dartCodeBlockInfoLine[of]!;
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

      final indentation = ' ' * match.namedGroup('indent')!.length;
      final infoLine = match.namedGroup('infoLine')!;

      final lines = replacement.split('\n');
      if (lines.length > 1 && lines.last.isEmpty) {
        lines.removeLast();
      }

      buffer
        ..write(text.substring(lastMatch?.end ?? 0, match.start))
        ..write(indentation)
        ..write('```')
        ..write(infoLine)
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
