// Stub implementation for platforms without dart:io support.
class File {
  File(String path);

  Future<void> writeAsBytes(List<int> bytes) async {
    throw UnsupportedError('File write is not supported on this platform.');
  }
}
