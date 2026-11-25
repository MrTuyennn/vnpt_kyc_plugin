import 'dart:io';

/// Dung lượng tối đa của một ảnh/file gửi lên (port từ app Wikex).
const ekycMaxImageBytes = 5 * 1024 * 1024;

/// `true` nếu file ở [path] lớn hơn [maxBytes].
Future<bool> isEkycFileTooLarge(
  String path, {
  int maxBytes = ekycMaxImageBytes,
}) async =>
    await File(path).length() > maxBytes;
