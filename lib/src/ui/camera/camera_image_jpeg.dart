import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:vnpt_kyc_plugin/src/ui/camera/camera_frame_util.dart';
import 'package:image/image.dart' as img;

import 'package:vnpt_kyc_plugin/src/ui/card_capture_image.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/preview_frame.dart';

Future<PreviewFrame?> encodePreviewFrame(
  CameraImage image, {
  required int quality,
  required int rotationDegrees,
  required bool mirrorHorizontally,
  bool cropCard = false,
  Size cardView = ekycOvalReferenceSize,
}) =>
    compute(_encode, (
      image,
      quality,
      rotationDegrees,
      mirrorHorizontally,
      cropCard,
      cardView.width,
      cardView.height,
    ));

PreviewFrame? _encode(
    (CameraImage, int, int, bool, bool, double, double) input) {
  final (
    image,
    quality,
    rotationDegrees,
    mirrorHorizontally,
    cropCard,
    viewWidth,
    viewHeight
  ) = input;
  try {
    var pixels = _decode(image);
    if (pixels == null) return null;
    if (rotationDegrees != 0) {
      pixels = img.copyRotate(pixels, angle: rotationDegrees);
    }
    if (mirrorHorizontally) img.flipHorizontal(pixels);
    if (cropCard) {
      if (pixels.width >= pixels.height) return null;
      pixels = cropToCardGuide(pixels, Size(viewWidth, viewHeight)).$1;
    }
    return PreviewFrame(
      width: pixels.width,
      height: pixels.height,
      jpeg: img.encodeJpg(pixels, quality: quality),
    );
  } catch (_) {
    return null;
  }
}

img.Image? _decode(CameraImage image) {
  if (image.format.group == ImageFormatGroup.bgra8888 &&
      image.planes.length == 1) {
    final p = image.planes[0];
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: p.bytes.buffer,
      bytesOffset: p.bytes.offsetInBytes,
      rowStride: p.bytesPerRow,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );
  }
  if (image.format.group == ImageFormatGroup.yuv420 &&
      image.planes.length >= 3) {
    return _yuv420ToImage(image);
  }
  return null;
}

img.Image? _yuv420ToImage(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final out = img.Image(width: width, height: height);
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  for (var y = 0; y < height; y++) {
    final yRow = y * yPlane.bytesPerRow;
    final uvRow = (y >> 1) * uvRowStride;
    for (var x = 0; x < width; x++) {
      final yIndex = yRow + x;
      final uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final yv = yPlane.bytes[yIndex];
      final uv = uPlane.bytes[uvIndex];
      final vv = vPlane.bytes[uvIndex];
      final r = (yv + 1.370705 * (vv - 128)).round().clamp(0, 255);
      final g = (yv - 0.337633 * (uv - 128) - 0.698001 * (vv - 128))
          .round()
          .clamp(0, 255);
      final b = (yv + 1.732446 * (uv - 128)).round().clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}
