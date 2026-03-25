/// Exception thrown when a file cannot be analyzed because it could not be
/// found.
class FileDoesNotExist implements Exception {
  /// Creates a new [FileDoesNotExist] exception.
  FileDoesNotExist(this.path);

  /// The path to the file that could not be found.
  final String path;

  @override
  String toString() => 'FileDoesNotExist: $path';
}

/// Exception thrown when a file cannot be analyzed because it has an
/// unsupported file type.
class UnsupportedFileType implements Exception {
  /// Creates a new [UnsupportedFileType] exception.
  UnsupportedFileType(this.path);

  /// The path to the file whose type is not supported.
  final String path;

  @override
  String toString() => 'UnsupportedFileType: $path';
}

/// Exception thrown when a requested package public API cannot be resolved.
class PublicApiFileNotFound implements Exception {
  /// Creates a new [PublicApiFileNotFound] exception.
  PublicApiFileNotFound(this.packageName);

  /// The package name whose public API could not be resolved.
  final String packageName;

  @override
  String toString() =>
      'Could not resolve package:$packageName/$packageName.dart.';
}
