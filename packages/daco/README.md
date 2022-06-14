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
- /// Formats the given [source]   string containing an entire Dart compilation unit.
+ /// Formats the given [source] string containing an entire Dart compilation
+ /// unit.
  Future<String> format(String source, {String? path}) async;
```

This is useful when writing and updating documentation comments and an edit
pushes some text beyond the preferred line length.

Example code in fenced code blocks that is marked as Dart code is formatted:

````diff
  /// Greets the user.
  ///
  /// ```dart
- /// greet(name: 'Alice',);
+ /// greet(
+ ///   name: 'Alice',
+ /// );
  /// ```
  void greet({required String name});
````

Formatting of example code and documentation comments is **recursive**. That
means documentation comments in example code are formatted too.

The example code is parsed and if it contains syntactic errors they are reported
with correct line and column numbers. This provides a basic check, ensuring that
the code is at least syntactically correct.

# Example code attributes

Example code can be annotated with attributes to influence how it is processed.

## `no_format`

If example code does not represent valid Dart, formatting can be disabled by
annotating it with the `no_format` attribute:

````dart
/// Greets the user.
///
/// ```dart no_format
/// greet(name: ...);
/// ```
void greet({required String name});
````

## `main`

Example code must represent a valid Dart file. Often times is preferable to
write example code as if it were contained in a function, but without the
function syntax and indentation.

By annotating example code with the `main` attribute, the code is wrapped in a
function before processing:

````dart
/// Greets the user.
///
/// ```dart main
/// greet(name: 'Alice');
/// ```
void greet({required String name});
````

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
