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
