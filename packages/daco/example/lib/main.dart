/// ```dart
/// class Foo {
///   void bar() {
///     const d = "Hallo";
///     const e = 0;
///   }
/// }
///
/// void main() {}
/// ```
///
/// ```dart main
/// final str = '$ajjjh';
/// const foo = '''
/// asdf
/// ''';
/// a({#foo: 'asdf'});
/// const bar = {foo: '$foo'};
/// print({foo: '$foo'});
/// const asdf = '';
/// ```
///
/// ```dart main multi_begin
/// const a = 'a';
/// ```
///
/// ```dart main multi_end
/// const b = '$a';
/// print(b);
/// ```
void main() {}
