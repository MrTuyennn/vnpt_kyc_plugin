import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/painting.dart' show Alignment, applyBoxFit, BoxFit;
import 'package:image/image.dart' as img;

import 'package:vnpt_kyc_plugin/src/ui/camera/camera_frame_util.dart';

/// Khung thẻ rộng bao nhiêu so với chiều ngang vùng nhìn thấy.
const cardGuideWidthRatio = 0.86;

Rect cardGuide(Size viewportSize) {
  const ratio = 1.586;
  final width = viewportSize.width * cardGuideWidthRatio;
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

/// [view] là kích thước vùng hiển thị preview trên màn hình (camera phủ kín,
/// [BoxFit.cover]); khung thẻ là 86% chiều ngang vùng đó, nằm giữa.
Future<CardCaptureImage> prepareCardCapture(Uint8List jpeg,
        {Size view = ekycOvalReferenceSize}) =>
    compute(_prepare, (jpeg, view.width, view.height));

CardCaptureImage _prepare((Uint8List, double, double) input) {
  final (jpeg, viewWidth, viewHeight) = input;
  final decoded = img.decodeJpg(jpeg);
  if (decoded == null) throw const FormatException('Invalid card JPEG');
  final orientation = decoded.exif.imageIfd.orientation;
  final upright = orientation == null || orientation == 1
      ? decoded
      : img.bakeOrientation(decoded);
  final (crop, top, bottom) =
      cropToCardGuide(upright, Size(viewWidth, viewHeight));
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

(img.Image, int, int) cropToCardGuide(img.Image upright,
    [Size view = ekycOvalReferenceSize]) {
  final size = Size(upright.width.toDouble(), upright.height.toDouble());
  // Preview center-crop (cover) cảm biến theo tỉ lệ của [view].
  final visible = Alignment.center.inscribe(
    applyBoxFit(BoxFit.cover, size, view).source,
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
