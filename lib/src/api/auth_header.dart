/// Chuẩn hoá header xác thực VNPT (port từ `EkycAuthHeader.kt` / `EkycVnptAuth`).
abstract final class EkycAuthHeader {
  static String _stripQuotes(String s) {
    var start = 0;
    var end = s.length;
    bool isQuote(String c) => c == '"' || c == "'";
    while (start < end && isQuote(s[start])) {
      start++;
    }
    while (end > start && isQuote(s[end - 1])) {
      end--;
    }
    return s.substring(start, end);
  }

  /// `Authorization: Bearer {JWT}` — hoặc chỉ `eyJ…` (tự thêm Bearer).
  /// Không double Bearer; giá trị JSON (`{...}`) giữ nguyên.
  static String authorization(String raw) {
    var t = _stripQuotes(raw.trim());
    if (t.isEmpty) return t;
    if (t.startsWith('{')) return t;
    while (t.toLowerCase().startsWith('bearer bearer ')) {
      t = t.substring(7).trimLeft();
    }
    if (t.toLowerCase().startsWith('bearer ')) {
      final jwt = t.substring(7).trimLeft();
      return '${t.substring(0, 6)} $jwt';
    }
    if (t.startsWith('eyJ')) return 'Bearer $t';
    return t;
  }

  static String trimCredential(String raw) => _stripQuotes(raw.trim());

  /// Mô tả "hình dạng" của token để log, không lộ nội dung.
  static String shape(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'empty';
    if (t.startsWith('{')) return 'json';
    if (t.toLowerCase().startsWith('bearer ')) return 'bearer';
    if (t.startsWith('eyJ')) return 'jwt(no Bearer prefix)';
    return 'opaque';
  }
}
