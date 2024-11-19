[![Version](https://badgen.net/pub/v/daco)](https://pub.dev/packages/daco)
[![CI](https://github.com/blaugold/daco/actions/workflows/ci.yaml/badge.svg)](https://github.com/blaugold/daco/actions/workflows/ci.yaml)

A tool for maintaining **Da**rt **co**mments (daco).

- Format doc comments as Markdown
- Format Dart code examples
- Analyze Dart code examples
- Analyzer plugin
  - Analyzes Dart code examples and provides errors

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

1. Optional: Install daco locally:

   ```shell
   dart pub add --dev daco
   ```

   When daco is executed within your project, the version that was resolved by
   `pub get` will be used. To fully lock the version of daco you either need to
   specify a fixed version (e.g. no `^`) in your `pubspec.yaml` or check
   `pubspec.lock` into your version control system. The latter option is
   recommended because it gives `pub get` more flexibility to resolve
   dependencies.

   By doing this you can ensure that all contributors to a project as well as
   the CI/CD pipeline use the same version of daco.

1. Format the Dart files within the current directory:

   ```shell
   daco format .
   ```

# Install analyzer plugin

1. Add `daco` as a development dependency to the each package where the plugin
   should be active:

   ```shell
   dart pub add --dev daco
   ```

1. Enable the plugin in the package's `analysis_options.yaml`:

   ```yaml
   analyzer:
     plugins:
       - daco
   ```

# Formatting

daco formats Dart files, including documentation comments.

prettier is used to format comments as Markdown. This means that the conventions
of prettier are applied, such as using `**` to bold text instead of `__`. A nice
feature of prettier is that Markdown tables are pretty-printed.

Prose is reprinted to optimally fit within the specified line length (defaults
to 80):

```diff
-/// Formats the given [source]   string containing an entire Dart compilation unit.
+/// Formats the given [source] string containing an entire Dart compilation
+/// unit.
Future<String> format(String source, {String? path}) async;
```

This is useful when writing and updating documentation comments, and an edit
pushes some text beyond the preferred line length.

Example code in fenced code blocks that is marked as Dart code is formatted:

````diff
 /// Greets the user.
 ///
 /// ```dart
-/// greet(name: 'Alice',);
+/// greet(
+///   name: 'Alice',
+/// );
 /// ```
 void greet({required String name});
````

Formatting of example code and documentation comments is **recursive**. That
means documentation comments in example code are formatted, too.

The example code is parsed and if it contains syntactic errors they are reported
with correct line and column numbers. This provides a basic check, ensuring that
the code is at least syntactically correct.

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

When formatting a preexisting codebase, special attention should be paid to the
location of dartdoc tags after formatting.

# Analyzing

daco analyzes the example code in documentation comments.

Take for example the following file:

````dart
/// Greets the user.
///
/// ```dart main
/// greet();
/// ```
void greet({required String name}) {}
````

The example code is not passing the required `name` parameter.

When running `daco analyze`, an error message with the correct error location is
printed:

```shell
$ daco analyze
lib/greeter.dart:4:5 • The named parameter 'name' is required, but there's no corresponding argument. • MISSING_REQUIRED_ARGUMENT
```

The package which contains the example code is automatically imported.

# Example code attributes

Example code can be annotated with attributes to influence how it is processed.

## `main`

Example code must represent a valid Dart file. Often it is preferable to write
example code as if it were contained in a function, but without the function
syntax and indentation.

By annotating example code with the `main` attribute the code is wrapped in a
`main` function before processing:

````dart
/// Greets the user.
///
/// ```dart main
/// greet(name: 'Alice');
/// ```
void greet({required String name}) {}
````

## `multi_begin` & `multi_end`

Sometimes it is useful to breaker larger examples into multiple code blocks,
explaining each block individually.

````dart
/// Greets the user.
///
/// The source of the user's name could be an environment variable:
///
/// ```dart main multi_begin
/// var name = Platform.environment['NAME'] || 'Alice';
/// ```
///
/// Let's make sure the name is not empty:
///
/// ```dart main
/// if (name.isEmpty) {
///   throw ArgumentError.value(name, 'name', 'must not be empty');
/// }
/// ```
///
/// Finally pass the `name` to `greet`:
///
/// ```dart main multi_end
/// greet(name: name);
/// ```
void greet({required String name}) {}
````

A code block annotated with `multi_begin` marks the beginning of a multi-part
code example and a code block annotated with `multi_end` the end. The annotated
code blocks, as well as all code blocks in between, belong to the same code
example.

All the code blocks of a multi-part code example are composed into one Dart
file. Multiple code blocks annotated with `main` are collected into a single
`main` function, where each block appears in the same order as in the source
file.

The `ignore` and `no_format` attributes can be used on code blocks that are part
of a multi-part code example and work as usual.

If the `no_analyze` is used on any one of the code blocks, the whole code
example won't be analyzed.

## `ignore`

If example code should not be processed, it can be ignored by annotating it with
the `ignore` attribute.

The example code below is not valid and would result in an error, but it is
instead ignored:

````dart
/// Greets the user.
///
/// ```dart ignore
/// greet(name: ...);
/// ```
void greet({required String name}) {}
````

## `no_format`

If example code should not be formatted, it can be annotated with the
`no_format` attribute:

````dart
/// Greets the user.
///
/// ```dart main no_format
/// // Keep this strange formatting.
/// greet(
///   name:
///      'Alice'
///         );
/// ```
void greet({required String name}) {}
````

## `no_analyze`

If example code should not be analyzed for semantic errors, it can be annotated
with the `no_analyze` attribute:

````dart
/// Greets the user.
///
/// ```dart main no_analyze
/// greet(name: 'Alice') as String;
/// ```
void greet({required String name}) {}
````

Syntactic errors will still be reported. To suppress all errors use the `ignore`
attribute.

# Hiding code

Sometimes code is required to make a code example complete, but the code is not
relevant for the reader.

This code can be hidden by placing it in a commented-out code block, while
making the block part of a multi-part code example.

````dart
/// Greets the user.
///
/// <!--
/// ```dart multi_begin
/// const name =  'Alice';
/// ```
/// -->
///
/// ```dart main multi_end
/// greet(name: name);
/// ```
void greet({required String name}) {}
````

# TODO

- [ ] Support formatting of end of line comments
- [ ] Support disabling formatting for a comment

# Ideas

- Integrate formatting with IDEs
- Analyze comments
  - Spelling
  - Punctuation
- Format Dart code in Markdown files
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
