import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'vnpt_kyc_plugin',
    dartOut: 'lib/src/platform/pigeon/native_ekyc.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/vnpt/vnpt_kyc_plugin/NativeEkyc.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.vnpt.vnpt_kyc_plugin'),
    swiftOut: 'ios/Classes/NativeEkyc.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
/// Chỉ những tham số engine native cần. Credential VNPT (token, key...) KHÔNG
/// được gửi xuống native: HTTP chạy hoàn toàn ở Dart (`VnptClient`).
class NativeEngineConfig {
  NativeEngineConfig({
    this.jpegQuality = 80,
    this.previewHeight = 180,
    this.ocrToken = '8928skjhfa89298jahga1771vbvb',
    this.isAutoCropParam = false,
  });

  int jpegQuality;
  int previewHeight;
  String ocrToken;
  bool isAutoCropParam;
}

/// Thông tin thiết bị để Dart dựng `client_session`.
class NativeDeviceInfo {
  NativeDeviceInfo({
    required this.platform,
    required this.model,
    required this.osVersion,
    required this.isSimulator,
    required this.deviceId,
    required this.appId,
  });

  /// `ANDROID` hoặc `IOS`.
  String platform;
  String model;
  /// Android: `Build.VERSION.SDK_INT`; iOS: `systemVersion`.
  String osVersion;
  bool isSimulator;
  /// Android: `ANDROID_ID`; iOS: `identifierForVendor`.
  String deviceId;
  /// Android: packageName; iOS: bundle identifier.
  String appId;
}

class CardPostCaptureResult {
  CardPostCaptureResult({
    required this.cropJpeg,
    required this.cropParam,
    required this.ocrToken,
  });

  Uint8List cropJpeg;
  String cropParam;
  String ocrToken;
}

@HostApi()
abstract class EkycNativeEngine {
  void configure(NativeEngineConfig config);
  void cardCreateInstance();
  void cardDeleteInstance();
  /// Returns MESSAGE_RESULT ordinal (see [MessageResult]).
  int cardValidateV2(Uint8List jpeg, bool isFront);
  /// Post-capture crop + crop_param + OCR token from native engine.
  CardPostCaptureResult cardPostCapture(Uint8List jpeg, bool isFront);

  void faceCreateInstance(int timeLimitSec);
  void faceDeleteInstance();
  /// 0 = far oval rect, 1 = near — must match `M.java` phase before process/crop.
  void faceSetOvalPhase(bool isFar);
  /// Camera preview J4 size (same as SDK `M.s` / TextureView), not JPEG size.
  void faceSetPreviewSize(int width, int height);
  int faceProcessFrame(Uint8List jpeg);
  /// JPEG cropped like SDK far/near portrait (engine ROI, scaled to previewHeight).
  Uint8List faceOvalCropJpeg(Uint8List jpeg);
  void faceNotifyCapture();
  String faceGet3DScan();
  String faceCaptureV1(String logLines);
}

@HostApi()
abstract class EkycDeviceApi {
  NativeDeviceInfo deviceInfo();
}
