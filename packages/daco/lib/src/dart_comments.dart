import 'dart:async';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:dart_style/dart_style.dart';

/// Function that takes a [comment] and returns the updated version of the
/// comment.
///
/// [lineLength] is the maximum length each line of the updated comment should
/// have.
///
/// [lineOffsets] are the offsets to the beginning of each line in [comment] in
/// the original source.
typedef CommentProcessor = FutureOr<String> Function(
  String comment,
  int lineLength,
  List<int> lineOffsets,
);

/// Processes documentation comments in a Dart source code with the given
/// [processor] and returns the updated source code.
Future<String> processComments({
  required String source,
  required CommentProcessor processor,
  String? path,
  int lineLength = 80,
}) async {
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  final errors = result.errors;
  if (errors.isNotEmpty) {
    throw FormatterException(errors);
  }

  final commentCollector = _CommentCollector();
  result.unit.accept(commentCollector);

  final commentNodes = commentCollector.comments;
  final commentStrings = <Comment, String>{};

  if (commentNodes.isEmpty) {
    return source;
  }

  await Future.wait(
    commentNodes.map((commentNode) async {
      final lineOffsets = <int>[];
      commentStrings[commentNode] = (await processor(
        commentNode.content(lineOffsets),
        commentNode.lineLength(result.lineInfo, lineLength),
        lineOffsets,
      ))
          .toCommentSource(commentNode.indentation(result.lineInfo));
    }),
  );

  final parts = <String>[];
  Comment? previousComment;

  for (final commentNode in commentNodes) {
    if (previousComment == null) {
      if (commentNode.offset != 0) {
        parts.add(source.substring(0, commentNode.offset));
      }
    } else {
      parts.add(source.substring(previousComment.end, commentNode.offset));
    }

    parts.add(commentStrings[commentNode]!);

    previousComment = commentNode;
  }

  if (previousComment != null) {
    parts.add(source.substring(previousComment.end));
  }

  return parts.join();
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

final _commentPrefixRegExp = RegExp('/// ?');

extension on Comment {
  /// The number of columns by which the comment is indented in the source.
  int indentation(LineInfo lineInfo) =>
      lineInfo.getLocation(offset).columnNumber - 1;

  /// The line length available for the comment content.
  int lineLength(LineInfo lineInfo, int lineLength) {
    final commentContentColumn = indentation(lineInfo) + '/// '.length;
    return lineLength - commentContentColumn;
  }

  /// The content of the comment.
  ///
  /// Populates the [lineOffsets] with the offsets to the beginning of each line
  /// in the source.
  String content(List<int> lineOffsets) => tokens
      .map(
        (token) =>
            // ignore: prefer_interpolation_to_compose_strings
            token.lexeme.replaceFirstMapped(_commentPrefixRegExp, (match) {
              final length = match.end - match.start;
              lineOffsets.add(token.offset + length);
              return '';
            }) +
            '\n',
      )
      .join();
}

extension on String {
  String toCommentSource(int indentation) {
    var isFirstLine = true;
    return trimRight().split('\n').map((line) {
      final leadingSpace = isFirstLine ? '' : ' ' * indentation;
      if (isFirstLine) {
        isFirstLine = false;
      }
      return line.isEmpty ? '$leadingSpace///' : '$leadingSpace/// $line';
    }).join('\n');
  }
}
