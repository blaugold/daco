import 'source.dart';

/// An attribute of a code block that influences how it is processed.
enum CodeBlockAttribute {
  /// The code block should not be formatted.
  ignore,

  /// The code block contains code for the body of the `main` function.
  main;

  /// Parses [CodeBlockAttribute]s in the info line of a fenced code block.
  static Iterable<CodeBlockAttribute> parseInfoLine(String infoLine) sync* {
    for (final word in infoLine.split(' ')) {
      switch (word.trim()) {
        case 'ignore':
          yield CodeBlockAttribute.ignore;
          break;
        case 'main':
          yield CodeBlockAttribute.main;
          break;
        default:
          continue;
      }
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
      attributes = CodeBlockAttribute.parseInfoLine(
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
