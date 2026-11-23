import 'dart:convert';

/// Best-effort parse VNPT API JSON for display (không validate schema).
class VnptJsonDisplay {
  static Map<String, dynamic>? decode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static List<MapEntry<String, String>> flatFields(Map<String, dynamic>? root) {
    if (root == null) return [];
    final out = <MapEntry<String, String>>[];
    void walk(String prefix, Object? v) {
      if (v is Map) {
        v.forEach((k, val) => walk(prefix.isEmpty ? '$k' : '$prefix.$k', val));
      } else if (v is List) {
        out.add(MapEntry(prefix, v.length.toString()));
      } else if (v != null) {
        final s = '$v';
        if (s.length > 200) {
          out.add(MapEntry(prefix, '${s.substring(0, 200)}…'));
        } else {
          out.add(MapEntry(prefix, s));
        }
      }
    }
    walk('', root);
    return out;
  }

  static String? topMessage(Map<String, dynamic>? root) {
    if (root == null) return null;
    return root['message']?.toString() ?? root['error_message']?.toString();
  }

  static bool httpOk(Map<String, dynamic>? root) {
    if (root == null) return false;
    final msg = root['message']?.toString().toLowerCase();
    if (msg == 'success' || msg == 'thành công') return true;
    return root.containsKey('object') && !root.containsKey('error');
  }
}