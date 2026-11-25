import 'dart:io';

/// Mặt giấy tờ khi quét bằng [VnptEkyc.scanCard].
enum VnptCardSide { front, back }

/// Kết quả quét một mặt CCCD: chỉ là file trên máy, chưa gọi API nào.
class CardScanResult {
  const CardScanResult({
    required this.side,
    required this.fullImagePath,
    required this.cropImagePath,
    required this.cropParam,
    required this.sessionDir,
  });

  final VnptCardSide side;

  /// Ảnh đầy đủ (toàn khung hình đã xoay đúng chiều).
  final String fullImagePath;

  /// Ảnh đã cắt theo khung quét.
  final String cropImagePath;

  /// Tỉ lệ cắt trên/dưới (`"top,bottom"`) tương ứng với [fullImagePath], để gửi
  /// kèm tham số `crop_param` của API OCR.
  final String cropParam;

  /// Thư mục chứa file của lần quét này.
  final String sessionDir;

  /// Xoá toàn bộ file của lần quét. Gọi khi đã upload xong.
  Future<void> delete() => _deleteDir(sessionDir);
}

/// Kết quả quét khuôn mặt 3D: chỉ là file trên máy, chưa gọi API nào.
class FaceScanResult {
  const FaceScanResult({
    required this.farImagePath,
    required this.farCropPath,
    required this.nearImagePath,
    required this.nearCropPath,
    required this.scan3dPath,
    required this.faceLogPath,
    required this.sessionDir,
  });

  /// Ảnh khuôn mặt xa / gần (khung hình đầy đủ) và bản cắt theo vùng oval.
  final String farImagePath;
  final String farCropPath;
  final String nearImagePath;
  final String nearCropPath;

  /// Dữ liệu quét 3D (`*.3dobj`) để gửi lên API liveness.
  final String scan3dPath;

  /// File log khuôn mặt; `null` nếu `enableFaceLog == false`.
  final String? faceLogPath;

  /// Thư mục chứa file của lần quét này.
  final String sessionDir;

  /// Xoá toàn bộ file của lần quét. Gọi khi đã upload xong.
  Future<void> delete() => _deleteDir(sessionDir);
}

Future<void> _deleteDir(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) await dir.delete(recursive: true);
}
