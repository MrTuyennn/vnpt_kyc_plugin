import 'dart:typed_data';

/// One camera stream frame and the dimensions of its encoded JPEG.
class PreviewFrame {
  const PreviewFrame({
    required this.width,
    required this.height,
    required this.jpeg,
  });

  final int width;
  final int height;
  final Uint8List jpeg;
}
