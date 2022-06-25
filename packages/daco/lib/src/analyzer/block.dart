// ignore: implementation_imports
import 'package:analyzer/error/error.dart';
// ignore: implementation_imports
import 'package:analyzer/src/generated/source.dart';

/// A block of [text] that is contained within a [Source].
///
/// The total region a block occupies within its [source] might be larger than
/// it's [text]. For example, for a documentation comment the [text] does not
/// include the prefix `/// ` in each line.
abstract class Block {
  /// The text of this block without syntax needed for embedding this block.
  String get text;

  /// The [LineInfo] for [text].
  LineInfo get lineInfo;

  /// Metadata associated with this block.
  List<String> get attributes;

  /// The [Source] that contains this block.
  Source get source;

  /// The block which contains the full [source] and therefor also this block.
  Block get rootBlock;

  /// The closest block that enclosed this block.
  ///
  /// The [rootBlock] contains all of the [source] and has no [enclosingBlock].
  Block? get enclosingBlock;

  /// The blocks directly enclosed by this block, in lexical order.
  List<Block> get enclosedBlocks;

  /// Translates an offset within the [text] of this block to an offset within
  /// the [text] of another block ([to]).
  ///
  /// If [to] is not specified it defaults to the [rootBlock].
  int translateOffset(int offset, {Block? to});

  /// Returns the available number of characters for one [of] the
  /// [enclosedBlocks], given the [lineLength] available for this block.
  int availableLineLength({required Block of, required int lineLength});

  /// Returns a new version of [text] in which the texts of [enclosedBlocks]
  /// have been replaced.
  String replaceEnclosedBlocks(Map<Block, String> replacements);
}

/// An attribute of a code block that influences how it is processed.
enum CodeBlockAttribute {
  /// The code block should not be processed.
  ignore,

  /// The code block contains code for the body of the `main` function.
  main,
}

/// A [Block] that contains Dart code.
abstract class DartBlock extends Block {
  /// The set of [CodeBlockAttribute] this block is annotated with.
  Set<CodeBlockAttribute> get codeBlockAttributes;

  /// Whether this block should be ignored for processing.
  bool get isIgnored;

  /// Whether this block contains code for the body of the `main` function.
  bool get isInMainBody;

  /// The [MarkdownBlock]s for all documentation comments contained in this
  /// block, in lexical order.
  List<MarkdownBlock> get documentationComments;

  /// Translates an [AnalysisError] that originated in this block's [text] to
  /// the correct location in [source].
  AnalysisError translateAnalysisError(AnalysisError error);
}

/// A [Block] that contains Markdown.
abstract class MarkdownBlock extends Block {
  /// The [DartBlock]s for all fenced code blocks contained in this
  /// block, in lexical order.
  List<DartBlock> get dartCodeBlocks;
}
