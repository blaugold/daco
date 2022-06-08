A tool for maintaining **Da**rt **co**mments (daco).

# Features

- Formatting of comments as Markdown, including embedded Dart code.

## TODO

- [x] Format doc comments as Markdown
- [x] Format Dart code in comments
- [ ] Docs
- [ ] Report correct location of parser error for embedded Dart code
- [ ] Handle failures in comments and embedded Dart code sections individual
- [ ] Support disabling formatting embedded Dart code
- [ ] Support standalone statements in embedded Dart code
- [ ] Support formatting simple comments

## Ideas

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
