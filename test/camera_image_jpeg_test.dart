import 'package:camera/camera.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/camera_image_jpeg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('iOS BGRA encoding preserves rows with padding and a buffer offset',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    const width = 16;
    const height = 24;
    const stride = width * 4 + 16;
    final buffer = Uint8List(stride * height + 8);
    final plane = Uint8List.sublistView(buffer, 8);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * stride + x * 4;
        plane[index + (2 - y ~/ 8)] = 255;
        plane[index + 3] = 255;
      }
    }

    // ignore: deprecated_member_use
    final frame = CameraImage.fromPlatformData({
      'format': 1111970369, // kCVPixelFormatType_32BGRA
      'width': width,
      'height': height,
      'planes': [
        {'bytes': plane, 'bytesPerRow': stride, 'bytesPerPixel': 4},
      ],
    });
    final encoded = (await encodePreviewFrame(
      frame,
      quality: 95,
      rotationDegrees: 0,
      mirrorHorizontally: false,
    ))!;
    final decoded = img.decodeJpg(encoded.jpeg)!;

    expect((encoded.width, encoded.height), (width, height));
    expect(decoded.getPixel(8, 4).r, greaterThan(240));
    expect(decoded.getPixel(8, 12).g, greaterThan(240));
    expect(decoded.getPixel(8, 20).b, greaterThan(240));
  });
}
