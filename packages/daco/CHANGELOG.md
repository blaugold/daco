## 0.2.3

 - **FEAT**: add analyzer plugin ([#22](https://github.com/blaugold/daco/issues/22)). ([c284a619](https://github.com/blaugold/daco/commit/c284a619cba1e35e8423d94f68fa6dca0708723a))

## 0.2.2+1

 - **DOCS**: fix spelling. ([269b8091](https://github.com/blaugold/daco/commit/269b8091e40319a5edc8b5a2877c05420c24223b))

## 0.2.2

 - **FEAT**: multi-part code examples ([#21](https://github.com/blaugold/daco/issues/21)). ([4c3157c2](https://github.com/blaugold/daco/commit/4c3157c2c3bdc1f9f8825fffa0371559a8e76aae))
 - **FEAT**: add `no_analyze` attribute ([#19](https://github.com/blaugold/daco/issues/19)). ([bcd41bbb](https://github.com/blaugold/daco/commit/bcd41bbb7cf22058bceeb332bd2874e7fcfac7ee))
 - **FEAT**: add `no_format` attribute ([#18](https://github.com/blaugold/daco/issues/18)). ([6273cf21](https://github.com/blaugold/daco/commit/6273cf214237a4e119fd329af3e45c7af0fba320))

## 0.2.1+1

 - **PERF**: persist `ByteStore` to cache analysis results ([#12](https://github.com/blaugold/daco/issues/12)). ([f8d054f1](https://github.com/blaugold/daco/commit/f8d054f193b0d95eaf3a36e6981db3ff18efe62d))

## 0.2.1

 - **FEAT**: add `analyze` command ([#11](https://github.com/blaugold/daco/issues/11)). ([6bed9e38](https://github.com/blaugold/daco/commit/6bed9e3898451656062a78313ea0bcc5e5e2f745))

## 0.2.0+1

 - **PERF**: use workers in prettier server ([#10](https://github.com/blaugold/daco/issues/10)). ([3d70b506](https://github.com/blaugold/daco/commit/3d70b50665a5301631fc00e1b01603de1fa07cde))
 - **DOCS**: move dartdoc section to correct place. ([c66f0e0c](https://github.com/blaugold/daco/commit/c66f0e0c72c165911df22c65291d22696ca0508a))

## 0.2.0

> Note: This release has breaking changes.

 - **FIX**: identing in `main` code blocks ([#9](https://github.com/blaugold/daco/issues/9)). ([ef09065a](https://github.com/blaugold/daco/commit/ef09065ae41aa657bcbcdc11882ff242f3047b59))
 - **FEAT**: log prettier server installation ([#8](https://github.com/blaugold/daco/issues/8)). ([c6903b63](https://github.com/blaugold/daco/commit/c6903b636a2adc864974c8046e8f82eed0cce112))
 - **FEAT**: add `main` attribute for example code ([#6](https://github.com/blaugold/daco/issues/6)). ([82010ae1](https://github.com/blaugold/daco/commit/82010ae1e62c515f4f7b1c64ab9f06e603d6fccf))
 - **BREAKING** **FEAT**: rename `no_format` attribute to `ignore` ([#7](https://github.com/blaugold/daco/issues/7)). ([0aa3f956](https://github.com/blaugold/daco/commit/0aa3f95648580387310985ce42f0480d2d869187))

## 0.1.1

 - **REFACTOR**: expose `LineInfo` on `Source` ([#4](https://github.com/blaugold/daco/issues/4)). ([bf943581](https://github.com/blaugold/daco/commit/bf94358147c0bf3e39e338d2f7f3c424a04a8aa6))
 - **FIX**: don't check code blocks tagged with `no_format` for syntactic errors ([#5](https://github.com/blaugold/daco/issues/5)). ([ea7fc5ab](https://github.com/blaugold/daco/commit/ea7fc5aba02c31d17444c2998536de18ea363138))
 - **FIX**: handle nested fenced code block ([#2](https://github.com/blaugold/daco/issues/2)). ([714fe124](https://github.com/blaugold/daco/commit/714fe1244b2536b96f7a64528f6b1a4a73d51d0e))
 - **FEAT**: report parser error locations in formatted file ([#3](https://github.com/blaugold/daco/issues/3)). ([e76ccf92](https://github.com/blaugold/daco/commit/e76ccf921be84408be1e2da91ec68d4f010e3304))
 - **DOCS**: add basic docs to README. ([6b9aae16](https://github.com/blaugold/daco/commit/6b9aae1655b453cf008423b8b15e35615b61b8a3))

## 0.1.0

- Initial version.
