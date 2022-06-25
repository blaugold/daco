import 'analyzer/block.dart';
import 'source.dart';

Iterable<CodeBlockAttribute> _parseInfoLine(String infoLine) sync* {
  for (final word in infoLine.split(' ')) {
    final value = CodeBlockAttribute.values.asNameMap()[word.trim()];
    if (value != null) {
      yield value;
    }
  }
}

final _codeBlockAttributesExpando =
    Expando<Set<CodeBlockAttribute>>('codeBlockAttributes');

/// Extension on [DartSource] for accessing [CodeBlockAttribute]s.
extension CodeBlockAttributeSourceExt on DartSource {
  /// The set of [CodeBlockAttribute]s this source has been annotated with.
  Set<CodeBlockAttribute> get codeBlockAttributes {
    var attributes = _codeBlockAttributesExpando[this];
    if (attributes != null) {
      return attributes;
    }

    final enclosingSource = this.enclosingSource;
    if (enclosingSource is MarkdownSource) {
      attributes = _parseInfoLine(
        enclosingSource.infoLine(of: this),
      ).toSet();
    } else {
      attributes = {};
    }

    return _codeBlockAttributesExpando[this] = attributes;
  }

  /// Whether this source should be ignored.
  bool get isIgnored => codeBlockAttributes.contains(CodeBlockAttribute.ignore);

  /// Whether this source contains code for the body of the `main` function.
  bool get isInMainFunction =>
      codeBlockAttributes.contains(CodeBlockAttribute.main);
}
