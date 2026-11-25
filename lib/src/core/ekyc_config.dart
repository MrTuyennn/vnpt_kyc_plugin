import 'dart:ui' show Locale;

import 'package:vnpt_kyc_plugin/src/l10n/ekyc_strings.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

/// Cấu hình phiên eKYC: credential VNPT + cờ luồng.
///
/// Credential chỉ dùng ở Dart (`VnptClient`), không gửi xuống native.
class EkycConfig {
  EkycConfig({
    this.accessToken = '',
    this.tokenId = '',
    this.tokenKey = '',
    this.challengeCode = '11111',
    this.baseUrl = 'https://api.idg.vnpt.vn',
    this.clientSession = '',
    this.stepId = 0,
    this.flowEkyc = '',
    this.documentType = -1,
    this.modeFaceOval = 0,
    this.checkLivenessFace = 2,
    this.stableFaceFrames = EkycArtifactNames.defaultStableFaceFrames,
    this.faceFlowTimeoutSec = EkycArtifactNames.defaultFaceTimeoutSec,
    this.jpegQuality = EkycArtifactNames.defaultJpegQuality,
    this.previewHeight = 180,
    this.ocrToken = EkycArtifactNames.defaultOcrTokenNoWatermark,
    this.isAutoCropParam = false,
    this.enableFaceLog = true,
    this.enableWatermark = false,
    this.sdkVersionLabel = '3.7.4',
    this.macAddress = defaultMacAddress,
    this.locale = const Locale('vi'),
    this.strings,
  });

  /// OCR token mặc định (không watermark).
  static const String defaultOcrToken =
      EkycArtifactNames.defaultOcrTokenNoWatermark;

  /// Giá trị header `mac-address` (giữ "TEST1" như bản native cũ).
  static const String defaultMacAddress = 'TEST1';

  String accessToken;
  String tokenId;
  String tokenKey;
  String challengeCode;
  String baseUrl;
  String clientSession;
  int stepId;
  String flowEkyc;
  int documentType;
  int modeFaceOval;
  int checkLivenessFace;
  int stableFaceFrames;
  int faceFlowTimeoutSec;
  int jpegQuality;
  int previewHeight;
  String ocrToken;
  bool isAutoCropParam;
  bool enableFaceLog;
  bool enableWatermark;
  String sdkVersionLabel;
  String macAddress;

  /// Ngôn ngữ giao diện quét/luồng (`vi`, `en`; khác thì dùng `vi`).
  Locale locale;

  /// Chuỗi giao diện riêng; ghi đè hoàn toàn [locale] nếu khác `null`.
  EkycStrings? strings;

  EkycStrings get resolvedStrings => strings ?? EkycStrings.of(locale);

  bool get isValidForApi =>
      accessToken.isNotEmpty &&
      tokenId.isNotEmpty &&
      tokenKey.isNotEmpty &&
      baseUrl.isNotEmpty;

  NativeEngineConfig toEngine() => NativeEngineConfig(
        jpegQuality: jpegQuality,
        previewHeight: previewHeight,
        ocrToken: ocrToken,
        isAutoCropParam: isAutoCropParam,
      );
}
