[![Version](https://badgen.net/pub/v/daco)](https://pub.dev/packages/daco)
[![CI](https://github.com/blaugold/daco/actions/workflows/ci.yaml/badge.svg)](https://github.com/blaugold/daco/actions/workflows/ci.yaml)

A tool for maintaining **Da**rt **co**mments (daco).

> This package is in an early stage of development. Please file an
> [issue][issues] if you find a bug or start a [discussion][discussions] if you
> have a question.

# Getting started

1. Make sure you have a recent version of NodeJS (>=14) installed and on the
   path. daco uses prettier to format Markdown.
1. Install daco globally:

   ```shell
   dart pub global activate daco
   ```

1. Format the Dart files within the current directory:

   ```shell
   daco format .
   ```

# Formatting

daco formats documentation comments in Dart files.

prettier is used to format comments as Markdown. This means that the conventions
of prettier are applied, such as using `**` to bold text instead of `__`. A nice
feature of prettier is that Markdown tables are pretty-printed.

Prose is reprinted to optimally fit within the specified line length (defaults
to 80):

```diff
- /// The quick brown fox     jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
+ /// The quick brown fox jumps over the lazy dog. The quick brown fox jumps over
+ /// the lazy dog.
  const foo = 'bar';
```

This is useful when writing and updating documentation comments and an edit
pushes some text beyond the preferred line length.

## Embedded Dart code

Fenced code blocks that are tagged with `dart` are formatted as Dart code.

````diff
  /// A top level constant.
  ///
  /// ```dart
- /// const fooList = [foo,];
+ /// const fooList = [
+ ///   foo,
+ /// ];
  /// ```
  const foo = 'bar';
````

The Dart code is parsed and if it contains syntactic errors they are reported
with correct line and column numbers. This provides a basic check for this code,
ensuring it is at least syntactically correct.

If the code does not represent a valid Dart file, formatting of it can be
disabled by tagging it with `no_format`:

````dart
/// A top level constant.
///
/// ```dart no_format
/// print(foo)
/// ```
const foo = 'bar';
````

Formatting of Dart code and documentation comments is **recursive**. That means
comments in fenced code blocks containing Dart code are formatted too.

## Dartdoc tags

Dartdoc supports tags for features such as templates. Dartdoc tags should be
separated from other content with an empty line, since prettier does not
recognize them as special and formats them as simple text:

```dart
/// A top level constant.
///
/// {@template foo}
///
/// The template content.
///
/// {@endtemplate}
const foo = 'bar';
```

When formatting a preexisting codebase special attention should be paid to the
location of dartdoc tags after formatting.

# TODO

- [ ] Support standalone statements in embedded Dart code
- [ ] Support formatting of end of line comments
- [ ] Support disabling formatting for a comment

# Ideas

- Integrate formatting with IDEs
- Analyze comments
  - Spelling
  - Punctuation
- Format Dart code in Markdown files
- Analyze Dart code embedded in Markdown
- Test Dart code embedded in Markdown
- Embedded templates in Markdown
  - Template is commented out
  - Below template, output of template is injected/updated

[issues]: https://github.com/blaugold/daco/issues
[discussions]: https://github.com/blaugold/daco/discussions

---

**Gabriel Terwesten** &bullet; **GitHub**
**[@blaugold](https://github.com/blaugold)** &bullet; **Twitter**
**[@GTerwesten](https://twitter.com/GTerwesten)** &bullet; **Medium**
**[@gabriel.terwesten](https://medium.com/@gabriel.terwesten)**
