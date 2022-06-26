import 'package:daco/src/analyzer/block.dart';
import 'package:daco/src/analyzer/result.dart';
import 'package:daco/src/analyzer/utils.dart';
import 'package:test/test.dart';

Block _parseBlock(String text, String extension, {bool allowErrors = false}) {
  final result = parseString(text: text, uri: 'text.$extension');
  if (!allowErrors) {
    expect(result.errors, isEmpty);
  }
  return result.block;
}

ParseStringResult _parseWithErrors(String text, String extension) {
  final result = parseString(
    text: text,
    uri: 'text.$extension',
    withErrorsInRootBlock: true,
  );
  expect(result.errors, isNotEmpty);
  return result;
}

DartBlock parseDart(String text, {bool allowErrors = false}) =>
    _parseBlock(text, 'dart', allowErrors: allowErrors) as DartBlock;

MarkdownBlock parseMarkdown(String text, {bool allowErrors = false}) =>
    _parseBlock(text, 'md', allowErrors: allowErrors) as MarkdownBlock;

ParseStringResult parseDartWithErrors(String text) =>
    _parseWithErrors(text, 'dart');

ParseStringResult parseMarkdownWithErrors(String text) =>
    _parseWithErrors(text, 'md');
