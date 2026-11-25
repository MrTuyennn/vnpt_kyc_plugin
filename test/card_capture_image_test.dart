import 'dart:ui';

import 'package:flutter/painting.dart' show Size;
import 'package:vnpt_kyc_plugin/src/ui/card_capture_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('màn hình cao: khung thẻ rộng 86% chiều ngang vùng nhìn thấy, nằm giữa',
      () async {
    // Ảnh 1080x1920 hiển thị cover trên màn 430x820 → vùng thấy rộng 1080*(430/820*1920/1080).
    final image = img.Image(width: 1080, height: 1920);
    final (crop, top, bottom) =
        cropToCardGuide(image, const Size(430, 820));
    const visibleWidth = 1920 * 430 / 820;
    expect(crop.width, closeTo(visibleWidth * cardGuideWidthRatio, 2));
    expect(crop.width / crop.height, closeTo(1.586, 0.02));
    expect((top + bottom) / 2, closeTo(960, 2));
  });

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
