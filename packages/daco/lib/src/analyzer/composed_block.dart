import 'package:analyzer/error/error.dart';
import 'package:collection/collection.dart';

import 'block.dart';
import 'block_impl.dart';

/// Represents a block of text that is composed of [String]s and [Block]s and
/// supports mapping of offsets back to the source block.
class ComposedBlock<T extends Block> {
  /// Creates a [ComposedBlock] from a list of [parts] of [String]s and [Block].
  ComposedBlock(
    Iterable<Object> parts, {
    this.uri,
  }) {
    text = _joinParts<T>(parts, _blocks);
  }

  /// The text of this block.
  late final String text;

  /// The URI of source this block.
  final String? uri;

  final _blocks = <Span, T>{};

  /// Translates an [offset] in [text] to the [Block] which is the source of the
  /// character at the given offset.
  ComposedBlockOffset<T>? translateOffset(int offset) {
    final entry =
        _blocks.entries.firstWhereOrNull((entry) => entry.key.contains(offset));
    if (entry == null) {
      return null;
    }

    final span = entry.key;
    final block = entry.value;

    return ComposedBlockOffset._(block, offset - span.offset);
  }

  /// Returns the offset to the start of [block] in [text].
  int blockOffset(T block) =>
      _blocks.entries.where((entry) => entry.value == block).first.key.offset;
}

String _joinParts<T extends Block>(
  Iterable<Object> parts,
  Map<Span, T> blocks,
) {
  final buffer = StringBuffer();
  var offset = 0;

  for (final part in parts) {
    final String text;
    if (part is String) {
      text = part;
    } else if (part is T) {
      text = part.text;
    } else {
      throw ArgumentError.value(
        part,
        'parts',
        'must contain only Strings and $T',
      );
    }

    if (part is T) {
      blocks[Span(offset: offset, length: text.length)] = part;
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

/// The result of translating an offset within in a [ComposedBlock] back to the
/// [block] which is the source of the character at the offset.
class ComposedBlockOffset<T extends Block> {
  ComposedBlockOffset._(this.block, this.offset);

  /// The [Block] which is the source of the character at the offset.
  final T block;

  /// The offset within [block].
  final int offset;
}

/// A [ComposedBlock] that represents a Dart compilation unit.
class ComposedDartBlock extends ComposedBlock<DartBlock> {
  /// Creates a [ComposedBlock] that represents a Dart compilation unit.
  ComposedDartBlock(super.parts, {super.uri});

  /// Translates an [AnalysisError], that was discovered in [text], to the
  /// location in the source of the [Block] that contains the error.
  AnalysisError? translateAnalysisError(AnalysisError error) {
    // Translates error to be relative to the [Document] of the
    // composed [DartSource] where the error occurred.

    final offset = translateOffset(error.offset);
    if (offset == null) {
      // The error occurred in the code that was added around the DartBlocks.
      return null;
    }

    return AnalysisError.forValues(
      source: offset.block.source,
      offset: offset.block.translateOffset(offset.offset),
      length: error.length,
      errorCode: error.errorCode,
      message: error.message,
      correctionMessage: error.correctionMessage,
    );
  }
}
