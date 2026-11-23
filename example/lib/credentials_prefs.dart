import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'build_env.dart';

class CredentialsPrefs {
  static const _k = [
    'access_token',
    'token_id',
    'token_key',
    'challenge_code',
    'base_url',
    'ocr_token',
    'check_liveness',
    'mode_face_oval',
    'stable_frames',
    'auto_crop',
    'face_log',
    'sdk_version',
  ];

  static EkycConfig _sanitize(EkycConfig c) => EkycConfig(
        accessToken: _trim(c.accessToken),
        tokenId: _trim(c.tokenId),
        tokenKey: _trim(c.tokenKey),
        challengeCode: _trim(c.challengeCode),
        baseUrl: _trim(c.baseUrl),
        clientSession: c.clientSession,
        stepId: c.stepId,
        flowEkyc: c.flowEkyc,
        documentType: c.documentType,
        modeFaceOval: c.modeFaceOval,
        checkLivenessFace: c.checkLivenessFace,
        stableFaceFrames: c.stableFaceFrames,
        faceFlowTimeoutSec: c.faceFlowTimeoutSec,
        jpegQuality: c.jpegQuality,
        previewHeight: c.previewHeight,
        ocrToken: _trim(c.ocrToken),
        isAutoCropParam: c.isAutoCropParam,
        enableFaceLog: c.enableFaceLog,
        enableWatermark: c.enableWatermark,
        sdkVersionLabel: c.sdkVersionLabel,
      );

  static String _trim(String s) {
    var t = s.trim();
    if (t.length >= 2 &&
        ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'")))) {
      t = t.substring(1, t.length - 1);
    }
    return t;
  }

  static Future<EkycConfig> load() async {
    if (BuildEkycEnv.isActive) {
      return _sanitize(BuildEkycEnv.toStore());
    }
    final p = await SharedPreferences.getInstance();
    return _sanitize(EkycConfig(
      accessToken: p.getString(_k[0]) ?? '',
      tokenId: p.getString(_k[1]) ?? '',
      tokenKey: p.getString(_k[2]) ?? '',
      challengeCode: p.getString(_k[3]) ?? '11111',
      baseUrl: p.getString(_k[4]) ?? 'https://api.idg.vnpt.vn',
      ocrToken: p.getString(_k[5]) ?? EkycConfig.defaultOcrToken,
      checkLivenessFace: p.getInt(_k[6]) ?? 2,
      modeFaceOval: p.getInt(_k[7]) ?? 0,
      stableFaceFrames: p.getInt(_k[8]) ?? 2,
      isAutoCropParam: p.getBool(_k[9]) ?? false,
      enableFaceLog: p.getBool(_k[10]) ?? true,
      sdkVersionLabel: p.getString(_k[11]) ?? '3.7.4',
    ));
  }

  static Future<void> save(EkycConfig c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k[0], c.accessToken);
    await p.setString(_k[1], c.tokenId);
    await p.setString(_k[2], c.tokenKey);
    await p.setString(_k[3], c.challengeCode);
    await p.setString(_k[4], c.baseUrl);
    await p.setString(_k[5], c.ocrToken);
    await p.setInt(_k[6], c.checkLivenessFace);
    await p.setInt(_k[7], c.modeFaceOval);
    await p.setInt(_k[8], c.stableFaceFrames);
    await p.setBool(_k[9], c.isAutoCropParam);
    await p.setBool(_k[10], c.enableFaceLog);
    await p.setString(_k[11], c.sdkVersionLabel);
  }
}