import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:vnpt_kyc_plugin/src/api/client_session.dart';
import 'package:vnpt_kyc_plugin/src/api/vnpt_client.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_config.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_sdk_log.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_session_artifacts.dart';
import 'package:vnpt_kyc_plugin/src/core/pipeline_models.dart';
import 'package:vnpt_kyc_plugin/src/core/vnpt_identity_response.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

class EkycCore {
  EkycCore({
    EkycNativeEngine? engine,
    EkycDeviceApi? deviceApi,
    http.Client? httpClient,
  })  : _engine = engine ?? EkycNativeEngine(),
        _deviceApi = deviceApi ?? EkycDeviceApi(),
        _httpClient = httpClient;

  final EkycNativeEngine _engine;
  final EkycDeviceApi _deviceApi;
  final http.Client? _httpClient;

  final _cardHints = StreamController<int>.broadcast();
  final _faceHints = StreamController<int>.broadcast();

  EkycConfig? _config;
  EkycSessionArtifacts? _artifacts;
  final StringBuffer _faceLog = StringBuffer();

  // Trạng thái oval đã gửi xuống native; chỉ gọi lại khi giá trị đổi.
  bool? _ovalIsFar;
  int? _ovalWidth;
  int? _ovalHeight;

  Stream<int> get cardHints => _cardHints.stream;
  Stream<int> get faceHints => _faceHints.stream;
  EkycSessionArtifacts? get artifacts => _artifacts;
  String get faceLogText => _faceLog.toString();

  Future<void> configure(EkycConfig store) async {
    _config = store;
    await _engine.configure(store.toEngine());
    EkycSdkLog.d('core',
        'configure baseUrl=${store.baseUrl} oval=${store.modeFaceOval}');
  }

  Future<EkycSessionArtifacts> startSession() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}/ekyc_session_${DateTime.now().millisecondsSinceEpoch}',
    );
    final art = EkycSessionArtifacts(dir);
    await art.ensureDir();
    _artifacts = art;
    _faceLog.clear();
    EkycSdkLog.d('core', 'session dir=${dir.path}');
    return art;
  }

  /// Restores a previously created session directory chosen by the host app.
  Future<EkycSessionArtifacts> resumeSession(Directory directory) async {
    if (!await directory.exists()) {
      throw StateError('Session directory missing');
    }
    final art = EkycSessionArtifacts(directory);
    await art.loadMetadata();
    _artifacts = art;
    _faceLog.clear();
    return art;
  }

  Future<void> startCardSession() async {
    await _engine.cardCreateInstance();
  }

  Future<void> endCardSession() async {
    await _engine.cardDeleteInstance();
  }

  Future<int> validateCardFrame(Uint8List jpeg, {required bool isFront}) async {
    final code = await _engine.cardValidateV2(jpeg, isFront);
    _cardHints.add(code);
    return code;
  }

  Future<int> commitCardCapture(
    Uint8List jpeg, {
    required bool isFront,
    Uint8List? guideJpeg,
    String? cropParam,
  }) async {
    final art = _artifacts;
    if (art == null) throw StateError('startSession() first');
    final quality =
        await validateCardFrame(guideJpeg ?? jpeg, isFront: isFront);
    if (quality != MessageResult.cardValid) return quality;
    final result = guideJpeg == null
        ? await _engine.cardPostCapture(jpeg, isFront)
        : CardPostCaptureResult(
            cropJpeg: guideJpeg,
            cropParam: cropParam ?? '0.0,0.0',
            ocrToken: _config?.ocrToken ?? art.ocrToken,
          );
    final fullPath = isFront ? art.frontFull : art.backFull;
    final cropPath = isFront ? art.frontCrop : art.backCrop;
    await File(fullPath).writeAsBytes(jpeg);
    await File(cropPath).writeAsBytes(result.cropJpeg);
    if (isFront) {
      art.cropParamFront = result.cropParam;
    } else {
      art.cropParamBack = result.cropParam;
    }
    art.ocrToken = result.ocrToken;
    await art.saveMetadata();
    EkycSdkLog.d('core',
        'card committed isFront=$isFront cropParam=${isFront ? art.cropParamFront : art.cropParamBack}');
    return quality;
  }

  Future<void> startOvalSession({bool? isFar}) async {
    _faceLog.clear();
    final sec =
        _config?.faceFlowTimeoutSec ?? EkycArtifactNames.defaultFaceTimeoutSec;
    await _engine.faceCreateInstance(sec);
    final mode = _config?.modeFaceOval ?? 0;
    try {
      await _setOvalPhase(isFar ?? mode != 2, force: true);
    } catch (_) {
      await _engine.faceDeleteInstance();
      rethrow;
    }
  }

  /// Sets the reference viewport used to map the native oval ROI into the bitmap.
  Future<void> setOvalPreviewSize(int width, int height) async {
    await _setOvalPreviewSize(width, height);
    EkycSdkLog.d('core', 'oval preview J4=${width}x$height');
  }

  Future<void> _setOvalPhase(bool isFar, {bool force = false}) async {
    if (!force && _ovalIsFar == isFar) return;
    await _engine.faceSetOvalPhase(isFar);
    _ovalIsFar = isFar;
  }

  Future<void> _setOvalPreviewSize(int width, int height) async {
    if (_ovalWidth == width && _ovalHeight == height) return;
    await _engine.faceSetPreviewSize(width, height);
    _ovalWidth = width;
    _ovalHeight = height;
  }

  Future<void> endOvalSession() async {
    await _engine.faceDeleteInstance();
  }

  Future<int> processOvalFrame(
    Uint8List jpeg, {
    required int phase,
    int frameMs = 0,
    required int frameWidth,
    required int frameHeight,
  }) async {
    await _setOvalPhase(phase == 0);
    await _setOvalPreviewSize(frameWidth, frameHeight);
    final code = await _engine.faceProcessFrame(jpeg);
    _faceHints.add(code);
    if (_config?.enableFaceLog ?? true) {
      _appendFaceLog(phase: phase, ms: frameMs, code: code);
    }
    return code;
  }

  void _appendFaceLog(
      {required int phase, required int ms, required int code}) {
    // TODO: `phase` chỉ nhận 0 (xa) / 1 (gần) nên `phase <= 1 ? 20 : 15` luôn ra 20.
    // Chưa xác định được ý nghĩa cột status (20/15) từ tài liệu VNPT nên giữ nguyên
    // hành vi cũ; cần đối chiếu với đặc tả log của SDK Android (`captureV1`).
    final status = phase <= 1 ? 20 : 15;
    _faceLog.writeln('$code;$ms;;;$status');
  }

  Future<void> notifyOvalCapture() async {
    await _engine.faceNotifyCapture();
  }

  Future<void> saveOvalFrame(Uint8List jpeg, {required bool isFar}) async {
    final art = _artifacts;
    if (art == null) throw StateError('startSession() first');
    await _setOvalPhase(isFar);
    final cropped = await _engine.faceOvalCropJpeg(jpeg);
    final path = isFar ? art.farPreview : art.nearPreview;
    await File(path).writeAsBytes(jpeg);
    await File(isFar ? art.farCrop : art.nearCrop).writeAsBytes(cropped);
  }

  Future<void> finalizeScan3d() async {
    final art = _artifacts;
    if (art == null) throw StateError('startSession() first');
    final scan = await _engine.faceGet3DScan();
    if (scan.trim().isEmpty) throw StateError('Empty 3D scan');
    final cap = await _engine.faceCaptureV1(_faceLog.toString());
    if (cap.trim().isEmpty) throw StateError('Empty capture signature');
    final content = '$scan|$cap';
    await File(art.scan3d).writeAsString(content);
    EkycSdkLog.d('core', 'scan3d len=${content.length} path=${art.scan3d}');
    if (_config?.enableFaceLog ?? true) {
      await File(art.faceLog).writeAsString(_faceLog.toString());
    }
  }

  Future<PipelineResult> runFullIdentity() async {
    final art = _artifacts;
    if (art == null) throw StateError('startSession() first');
    if (_config != null && !_config!.isValidForApi) {
      return PipelineResult(
        success: false,
        errorCode: 'CONFIG',
        errorMessage: 'Missing access token / token-id / token-key / baseUrl',
      );
    }
    EkycSdkLog.d('core', 'pipeline runFullIdentity…');
    final r = await runFullIdentityFromPaths(art.toPaths());
    EkycSdkLog.d('core', 'pipeline success=${r.success} err=${r.errorMessage}');
    return r;
  }

  Future<PipelineResult> runFullIdentityFromPaths(
      FullIdentityArtifactPaths paths) async {
    Future<bool> hasFile(String path) async {
      if (path.isEmpty) return false;
      final file = File(path);
      return await file.exists() && await file.length() > 0;
    }

    Future<bool> hasImage(String full, String crop) async =>
        await hasFile(full) || await hasFile(crop);
    try {
      if (!await hasImage(paths.frontFullPath, paths.frontCropPath) ||
          !await hasImage(paths.backFullPath, paths.backCropPath)) {
        return PipelineResult(
            errorCode: 'CARD_IMAGES',
            errorMessage: 'Thiếu ảnh mặt trước hoặc mặt sau CCCD.');
      }
      if (!await hasImage(paths.farPreviewPath, paths.farCropPath) ||
          !await hasImage(paths.nearPreviewPath, paths.nearCropPath) ||
          !await hasFile(paths.scan3dPath)) {
        return PipelineResult(
            errorCode: 'OVAL_FILES',
            errorMessage: 'Thiếu ảnh hoặc dữ liệu xác thực khuôn mặt.');
      }
      final parts = (await File(paths.scan3dPath).readAsString()).split('|');
      if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
        return PipelineResult(
            errorCode: 'SCAN3D',
            errorMessage: 'Dữ liệu xác thực khuôn mặt không đầy đủ.');
      }
      final config = _config;
      if (config == null) {
        return PipelineResult(
            errorCode: 'CONFIG', errorMessage: 'Call configure() first');
      }
      final device = await _deviceApi.deviceInfo();
      final session = buildClientSession(
        device: device,
        sdkVersionLabel: config.sdkVersionLabel,
        override: config.clientSession,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      // Client do EkycCore tạo thì EkycCore đóng; client do host truyền vào thì host đóng.
      final client = VnptClient(
        config: config,
        clientSession: session,
        httpClient: _httpClient,
      );
      try {
        return verifyVnptIdentity(await client.runFullIdentity(paths));
      } finally {
        if (_httpClient == null) client.close();
      }
    } on FileSystemException {
      return PipelineResult(
          errorCode: 'ARTIFACTS',
          errorMessage: 'Không đọc được ảnh hoặc dữ liệu xác thực.');
    } on FormatException {
      return PipelineResult(
          errorCode: 'SCAN3D',
          errorMessage: 'Dữ liệu xác thực khuôn mặt không đúng định dạng.');
    } on PlatformException catch (error) {
      return PipelineResult(
          errorCode: error.code,
          errorMessage: 'Không lấy được thông tin thiết bị.');
    }
  }
}
