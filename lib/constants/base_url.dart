class BaseUrl {
  static const String baseUrl = 'https://server.emaeducation.edu.np/api';
  static const String imageUrl = 'https://server.emaeducation.edu.np/api/res';

  // static const String baseUrl = 'http://46.62.152.166:8787/api';
  // static const String imageUrl = 'http://46.62.152.166:8787/api/res';

  /// Builds a full URL for a stored resource (file / icon / media).
  ///
  /// Server paths come back in a few shapes ('uploads/x.pdf', '/uploads/x.pdf',
  /// 'res/uploads/x.pdf' or already absolute), so normalise them all onto the
  /// `/api/res/...` route — hitting `/api/<path>` directly returns 404.
  static String resUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final clean = path.replaceFirst(RegExp(r'^/+'), '');
    if (clean.startsWith('res/')) return '$baseUrl/$clean';
    return '$imageUrl/$clean';
  }
}
