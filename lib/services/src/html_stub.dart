// Stub implementation for platforms without dart:html support.
class Blob {
  Blob(List<Object?> parts, String type);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => throw UnsupportedError('HTML URL creation is not supported on this platform.');
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {}

class Document {
  dynamic createElement(String name) => throw UnsupportedError('HTML elements are not supported on this platform.');
  dynamic get body => null;
}

Document get document => throw UnsupportedError('HTML document is not supported on this platform.');
