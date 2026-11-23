import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/painting.dart' show Alignment, applyBoxFit, BoxFit;
import 'package:image/image.dart' as img;

import 'package:vnpt_kyc_plugin/src/ui/camera/camera_frame_util.dart';

Rect cardGuide(Size viewportSize) {
  const ratio = 1.586;
  final width = viewportSize.width * 0.86;
  return Rect.fromCenter(
    center: viewportSize.center(Offset.zero),
    width: width,
    height: width / ratio,
  );
}

typedef CardCaptureImage = ({
  Uint8List full,
  Uint8List crop,
  String cropParam,
});

Future<CardCaptureImage> prepareCardCapture(Uint8List jpeg) =>
    compute(_prepare, jpeg);

CardCaptureImage _prepare(Uint8List jpeg) {
  final decoded = img.decodeJpg(jpeg);
  if (decoded == null) throw const FormatException('Invalid card JPEG');
  final orientation = decoded.exif.imageIfd.orientation;
  final upright = orientation == null || orientation == 1
      ? decoded
      : img.bakeOrientation(decoded);
  final (crop, top, bottom) = cropToCardGuide(upright);
  // VNPT's crop_param describes the top/bottom margins in the full image.
  final topRatio = (top / upright.height).toStringAsFixed(2);
  final bottomRatio =
      ((upright.height - bottom) / upright.height).toStringAsFixed(2);
  return (
    full: identical(upright, decoded)
        ? jpeg
        : img.encodeJpg(upright, quality: 94),
    crop: img.encodeJpg(crop, quality: 94),
    cropParam: '$topRatio,$bottomRatio',
  );
}

(img.Image, int, int) cropToCardGuide(img.Image upright) {
  final size = Size(upright.width.toDouble(), upright.height.toDouble());
  // The preview center-crops the sensor to this same portrait aspect ratio.
  final visible = Alignment.center.inscribe(
    applyBoxFit(BoxFit.cover, size, ekycOvalReferenceSize).source,
    Offset.zero & size,
  );
  final rect = cardGuide(visible.size).shift(visible.topLeft);
  final left = rect.left.floor().clamp(0, upright.width - 1);
  final top = rect.top.floor().clamp(0, upright.height - 1);
  final right = rect.right.ceil().clamp(left + 1, upright.width);
  final bottom = rect.bottom.ceil().clamp(top + 1, upright.height);
  final crop = img.copyCrop(
    upright,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );

  return (crop, top, bottom);
}
