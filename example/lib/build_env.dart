import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

/// Baked in at compile time via `--dart-define-from-file=env.local.json`.
abstract final class BuildEkycEnv {
  static const accessToken = String.fromEnvironment('ACCESS_TOKEN');
  static const tokenId = String.fromEnvironment('TOKEN_ID');
  static const tokenKey = String.fromEnvironment('TOKEN_KEY');
  static const challengeCode = String.fromEnvironment('CHALLENGE_CODE', defaultValue: '11111');
  static const baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'https://api.idg.vnpt.vn');

  static const ocrToken = String.fromEnvironment(
    'OCR_TOKEN',
    defaultValue: EkycConfig.defaultOcrToken,
  );

  static const checkLivenessFace = int.fromEnvironment('CHECK_LIVENESS_FACE', defaultValue: 2);
  static const modeFaceOval = int.fromEnvironment('MODE_FACE_OVAL', defaultValue: 0);
  static const stableFaceFrames = int.fromEnvironment('STABLE_FACE_FRAMES', defaultValue: 2);
  static const isAutoCropParam = bool.fromEnvironment('IS_AUTO_CROP_PARAM', defaultValue: false);
  static const enableFaceLog = bool.fromEnvironment('ENABLE_FACE_LOG', defaultValue: true);
  static const sdkVersionLabel = String.fromEnvironment('SDK_VERSION_LABEL', defaultValue: '3.7.4');

  /// True when you built with a non-empty ACCESS_TOKEN (minimum gate).
  static bool get isActive =>
      accessToken.isNotEmpty && tokenId.isNotEmpty && tokenKey.isNotEmpty && baseUrl.isNotEmpty;

  static EkycConfig toStore() => EkycConfig(
        accessToken: accessToken,
        tokenId: tokenId,
        tokenKey: tokenKey,
        challengeCode: challengeCode,
        baseUrl: baseUrl,
        ocrToken: ocrToken,
        checkLivenessFace: checkLivenessFace,
        modeFaceOval: modeFaceOval,
        stableFaceFrames: stableFaceFrames,
        isAutoCropParam: isAutoCropParam,
        enableFaceLog: enableFaceLog,
        sdkVersionLabel: sdkVersionLabel,
      );
}