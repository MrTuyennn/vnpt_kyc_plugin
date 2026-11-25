import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:flutter/painting.dart';

import 'package:vnpt_kyc_plugin/src/ui/camera/camera_capture_gate.dart';

/// Final still capture (shutter sound) — use only when committing card / oval save.
Future<Uint8List?> captureStillJpeg(CameraController controller) async {
  if (controller.value.isStreamingImages) {
    await controller.stopImageStream();
  }
  return CameraCaptureGate.instance.captureJpeg(controller);
}

@Deprecated('Use preview stream or captureStillJpeg')
Future<Uint8List?> capturePreviewJpeg(CameraController controller) =>
    captureStillJpeg(controller);

/// User-facing oval in the SDK view's coordinate space.
Rect normalizedOvalOverlay({required bool isFar, bool useIosGuide = false}) {
  if (useIosGuide) {
    // ICSdkEKYC 3.7.1: on iPhone the far oval is W/2 × 3W/4.
    // actionZoomOut scales its width by 1.5 and its height by 1.75.
    return Rect.fromCenter(
      center: const Offset(0.5, 0.5),
      width: isFar ? 0.5 : 0.5 * 1.5,
      height: isFar ? 0.5625 : 0.5625 * 1.75,
    );
  }
  if (isFar) {
    return const Rect.fromLTRB(
      EkycArtifactNames.farLeft,
      EkycArtifactNames.farTop,
      EkycArtifactNames.farRight,
      EkycArtifactNames.farBottom,
    );
  }
  return const Rect.fromLTRB(
    EkycOvalOverlayGuide.nearLeft,
    EkycOvalOverlayGuide.nearTop,
    EkycOvalOverlayGuide.nearRight,
    EkycOvalOverlayGuide.nearBottom,
  );
}

// SDK 3.7.4 sizes the portrait guide and camera container with a centered
// 3:4 rectangle, regardless of the capture buffer assigned by the device.
const ekycOvalReferenceSize = Size(480, 640);

Rect ovalViewport(Size size) => Alignment.center.inscribe(
      applyBoxFit(BoxFit.contain, ekycOvalReferenceSize, size).destination,
      Offset.zero & size,
    );

Rect projectOvalGuide(Rect normalized, Rect viewport) => Rect.fromLTRB(
      viewport.left + normalized.left * viewport.width,
      viewport.top + normalized.top * viewport.height,
      viewport.left + normalized.right * viewport.width,
      viewport.top + normalized.bottom * viewport.height,
    );

/// Vùng 3:4 giữa ảnh preview mà engine dùng làm hệ toạ độ cho oval
/// (khớp `EkycOvalGeometry.letterboxInBitmap` bên native).
Rect ovalRegionInPreview(Size preview) => Alignment.center.inscribe(
      applyBoxFit(BoxFit.contain, ekycOvalReferenceSize, preview).destination,
      Offset.zero & preview,
    );

/// Oval chuẩn hoá (theo vùng 3:4 của ảnh) → toạ độ màn hình khi preview phủ kín
/// ([BoxFit.cover]). Oval vẽ trùng đúng vùng engine cắt, dù màn hình dài hay ngắn.
Rect ovalGuideOnScreen({
  required Rect normalized,
  required Size preview,
  required Size screen,
}) {
  final inImage = projectOvalGuide(normalized, ovalRegionInPreview(preview));
  return previewRectToScreen(inImage, preview: preview, screen: screen);
}

/// Chiếu một rect trong toạ độ ảnh preview sang màn hình khi hiển thị [BoxFit.cover].
Rect previewRectToScreen(
  Rect rect, {
  required Size preview,
  required Size screen,
}) {
  final shown = applyBoxFit(BoxFit.cover, preview, screen);
  final origin =
      Alignment.center.inscribe(shown.source, Offset.zero & preview).topLeft;
  final scale = screen.width / shown.source.width;
  return Rect.fromLTRB(
    (rect.left - origin.dx) * scale,
    (rect.top - origin.dy) * scale,
    (rect.right - origin.dx) * scale,
    (rect.bottom - origin.dy) * scale,
  );
}

/// Map a normalized rectangle onto a centered, aspect-preserving preview.
Rect ovalRectOnView({
  required Rect normalized,
  required Size viewSize,
  required Size previewSize,
}) {
  final fitted = applyBoxFit(BoxFit.contain, previewSize, viewSize).destination;
  return projectOvalGuide(
    normalized,
    Alignment.center.inscribe(
      previewSize.isEmpty ? viewSize : fitted,
      Offset.zero & viewSize,
    ),
  );
}

/// Portrait UI: ensure preview height >= width (typical front camera J4).
Size portraitPreviewSize(CameraController controller) {
  final ps = controller.value.previewSize;
  if (ps == null) return const Size(480, 640);
  var w = ps.width.toDouble();
  var h = ps.height.toDouble();
  if (w > h) {
    final t = w;
    w = h;
    h = t;
  }
  return Size(w, h);
}

/// @deprecated use [normalizedOvalOverlay]
Rect normalizedOvalRect({required bool isFar}) =>
    normalizedOvalOverlay(isFar: isFar);
