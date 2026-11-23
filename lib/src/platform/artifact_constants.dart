/// File naming parity with Android `Q1` / `M` (see `docs/sdk2/artifacts-parity.md`).
abstract final class EkycArtifactNames {
  static const String scan3dFile = '3DFace_portrait.3dobj';
  static const String farPreview = 'far_portrait_preview';
  static const String farCrop = 'far_portrait_cropped_preview';
  static const String nearPreview = 'near_portrait_preview';
  static const String nearCrop = 'near_portrait_cropped_preview';

  static const String defaultOcrTokenNoWatermark =
      '8928skjhfa89298jahga1771vbvb';

  static const int defaultJpegQuality = 80;
  static const int defaultStableFaceFrames = 2;
  static const int defaultFaceTimeoutSec = 120;

  /// Normalized oval rects (Android `M.e()` preview space).
  static const double farLeft = 0.2413;
  static const double farTop = 0.2101;
  static const double farRight = 0.7587;
  static const double farBottom = 0.7899;

  static const double nearLeft = 0.0595;
  static const double nearTop = 0.0935;
  static const double nearRight = 0.9405;
  static const double nearBottom = 0.9065;
}

/// Oval UI gần — `EkycFaceOvalView` (AAR 3.7.4); engine near vẫn `M.r` (0.0595…).
abstract final class EkycOvalOverlayGuide {
  static const double nearLeft = 0.1235;
  static const double nearTop = 0.0217;
  static const double nearRight = 0.8765;
  static const double nearBottom = 0.9783;
}