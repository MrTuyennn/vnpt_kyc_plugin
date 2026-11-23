import 'package:vnpt_kyc_plugin/src/ui/card_capture_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('card crop and margins project from the portrait guide', () async {
    final jpeg = img.encodeJpg(img.Image(width: 480, height: 854));
    final capture = await prepareCardCapture(jpeg);
    final cropped = img.decodeJpg(capture.crop)!;

    expect(capture.full, jpeg);
    expect((cropped.width, cropped.height), (414, 262));
    expect(capture.cropParam, '0.35,0.35');
  });

  test('full and crop are upright when the still uses EXIF orientation',
      () async {
    final image = img.Image(width: 640, height: 480);
    image.exif.imageIfd.orientation = 6;
    final capture = await prepareCardCapture(img.encodeJpg(image));
    final full = img.decodeJpg(capture.full)!;
    final cropped = img.decodeJpg(capture.crop)!;

    expect((full.width, full.height), (480, 640));
    expect((cropped.width, cropped.height), (414, 262));
    expect(capture.cropParam, '0.30,0.30');
  });
}
