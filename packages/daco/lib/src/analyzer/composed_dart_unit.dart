import 'package:analyzer/error/error.dart';
import 'package:collection/collection.dart';

import 'block.dart';
import 'block_impl.dart';

class ComposedDartUnit {
  factory ComposedDartUnit(Iterable<Object> parts, {String? uri}) {
    final dartBlocks = <BlockSpan, DartBlock>{};
    final text = _joinParts(parts, dartBlocks);
    return ComposedDartUnit._(
      text: text,
      uri: uri,
      dartBlocks: dartBlocks,
    );
  }

  ComposedDartUnit._({
    required this.text,
    this.uri,
    required Map<BlockSpan, DartBlock> dartBlocks,
  }) : _dartBlocks = dartBlocks;

  final String text;

  final String? uri;

  final Map<BlockSpan, DartBlock> _dartBlocks;

  static String _joinParts(
    Iterable<Object> parts,
    Map<BlockSpan, DartBlock> enclosedSources,
  ) {
    final buffer = StringBuffer();
    var offset = 0;

    for (final part in parts) {
      final String text;
      if (part is String) {
        text = part;
      } else if (part is DartBlock) {
        text = part.text;
      } else {
        throw ArgumentError.value(
          part,
          'parts',
          'must contain only Strings and DartBlocks',
        );
      }

      if (part is DartBlock) {
        enclosedSources[BlockSpan(offset: offset, length: text.length)] = part;
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

  AnalysisError translateAnalysisError(AnalysisError error) {
    // Translates error to be relative to the [Document] of the
    // composed [DartSource] where the error occurred.

    final entry = _findDartBlockByOffset(error.offset);
    if (entry == null) {
      // The error occurred in the code that was added around the DartSources,
      // which we attribute to this source.
      return error;
    }

    final span = entry.key;
    final block = entry.value;

    return AnalysisError.forValues(
      block.source,
      block.translateOffset(error.offset - span.offset),
      error.length,
      error.errorCode,
      error.message,
      error.correctionMessage,
    );
  }

  MapEntry<BlockSpan, DartBlock>? _findDartBlockByOffset(int offset) =>
      _dartBlocks.entries
          .firstWhereOrNull((entry) => entry.key.contains(offset));
}
