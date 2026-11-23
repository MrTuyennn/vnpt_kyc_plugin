import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:path/path.dart' as p;
import 'package:vnpt_kyc_plugin/src/api/auth_header.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_config.dart';
import 'package:vnpt_kyc_plugin/src/core/pipeline_models.dart';

/// Lỗi một bước gọi API VNPT. [code] là `UPLOAD`, `API` hoặc `PIPELINE`.
class VnptApiException implements Exception {
  VnptApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Client HTTP gọi API VNPT (upload file, OCR, liveness 3D).
///
/// Port từ `EkycVnptHttp.kt` + `EkycPipelineBridge.kt` (Android) /
/// `EkycVnptHttp.swift` + `EkycPipelineBridge.swift` (iOS).
class VnptClient {
  VnptClient({
    required this.config,
    required this.clientSession,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 120),
  }) : _http = httpClient ?? http.Client();

  final EkycConfig config;
  final String clientSession;
  final Duration timeout;
  final http.Client _http;

  String get _base => config.baseUrl.replaceAll(RegExp(r'/+$'), '');

  void close() => _http.close();

  Map<String, String> _authHeaders() {
    final h = <String, String>{};
    if (config.accessToken.trim().isNotEmpty) {
      h['Authorization'] = EkycAuthHeader.authorization(config.accessToken);
    }
    final tokenId = EkycAuthHeader.trimCredential(config.tokenId);
    final tokenKey = EkycAuthHeader.trimCredential(config.tokenKey);
    if (tokenId.isNotEmpty) h['token-id'] = tokenId;
    if (tokenKey.isNotEmpty) h['token-key'] = tokenKey;
    if (config.ocrToken.isNotEmpty) h['Vnpt-Token'] = config.ocrToken;
    return h;
  }

  /// `POST /file-service/v1/addFile` (multipart). Trả về `object.hash`.
  Future<String> uploadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw VnptApiException('UPLOAD', 'Missing file: $path');
    }
    final name = p.basename(path);
    final stem = p.basenameWithoutExtension(path);
    final mime = name.startsWith('3DFace_portrait')
        ? MediaType('text', 'plain')
        : MediaType('image', 'jpeg');
    final url = Uri.parse('$_base/file-service/v1/addFile');
    final req = http.MultipartRequest('POST', url)
      ..headers.addAll(_authHeaders())
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: name,
        contentType: mime,
      ))
      ..fields['title'] = stem
      ..fields['description'] = stem;
    _logRequest(url, req.headers, {
      'file': name,
      'file_content_type': mime.mimeType,
      'title': stem,
      'description': stem,
    });
    final text = await _send(req, 'UPLOAD', path);
    return _parseHash(text);
  }

  String _parseHash(String body) {
    Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      throw VnptApiException('UPLOAD', 'No hash in response');
    }
    final obj = root is Map ? root['object'] : null;
    final hash = obj is Map ? obj['hash'] : null;
    if (hash is! String || hash.trim().isEmpty) {
      throw VnptApiException('UPLOAD', 'No hash in response');
    }
    return hash;
  }

  /// `POST /ai/v1/ocr/id?challenge_code=…`.
  Future<String> ocrId({
    required String imgFrontHash,
    String? imgBackHash,
    required String cropParam,
  }) {
    final url =
        Uri.parse('$_base/ai/v1/ocr/id?challenge_code=${config.challengeCode}');
    final body = <String, Object?>{
      'type': config.documentType,
      'img_front': imgFrontHash,
      if (imgBackHash != null && imgBackHash.trim().isNotEmpty)
        'img_back': imgBackHash,
      'client_session': clientSession,
      'token': config.ocrToken,
      'crop_param': cropParam,
      if (config.flowEkyc.trim().isNotEmpty) ...{
        'flow': config.flowEkyc,
        'step_id': config.stepId,
      } else if (config.stepId != 0)
        'step_id': config.stepId,
    };
    return _postJson(url, body);
  }

  /// iBeta (`checkLivenessFace == 1`): `/ai/v1/face/liveness-3d`,
  /// ngược lại `/ai/v1/standard/face/liveness-3d`.
  Future<String> liveness3d({
    required String farHash,
    required String nearHash,
    required String scan3dHash,
  }) {
    final path = config.checkLivenessFace == 1
        ? '/ai/v1/face/liveness-3d'
        : '/ai/v1/standard/face/liveness-3d';
    final url = Uri.parse('$_base$path?challenge_code=${config.challengeCode}');
    final body = <String, Object?>{
      'far_img': farHash,
      'near_img': nearHash,
      'scan3d': scan3dHash,
      'client_session': clientSession,
      if (config.flowEkyc.trim().isNotEmpty)
        'flow': config.flowEkyc
      else ...{
        'token': config.ocrToken,
        'step_id': config.stepId,
      },
    };
    return _postJson(url, body);
  }

  Future<String> _postJson(Uri url, Map<String, Object?> body) async {
    final req = http.Request('POST', url)
      ..headers.addAll(_authHeaders())
      ..headers['Content-Type'] = 'application/json'
      ..headers['mac-address'] = config.macAddress
      ..body = jsonEncode(body);
    _logRequest(url, req.headers, body);
    return _send(req, 'API', url.toString());
  }

  Future<String> _send(http.BaseRequest req, String code, String where) async {
    final http.Response resp;
    try {
      resp = await http.Response.fromStream(
        await _http.send(req).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      _log('network_error timeout');
      // Android/OkHttp: lỗi mạng (IOException) không phải FlutterError → code PIPELINE.
      throw VnptApiException('PIPELINE', 'Timeout sau ${timeout.inSeconds}s');
    } on SocketException catch (e) {
      _log('network_error ${e.runtimeType}');
      throw VnptApiException('PIPELINE', e.message);
    } on http.ClientException catch (e) {
      _log('network_error ${e.runtimeType}');
      throw VnptApiException('PIPELINE', e.message);
    }
    final text = utf8.decode(resp.bodyBytes, allowMalformed: true);
    _logResponse(resp.statusCode, text);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw VnptApiException(code, 'HTTP ${resp.statusCode}: $text');
    }
    return text;
  }

  /// Chạy toàn bộ: upload 5 file → OCR → liveness 3D.
  ///
  /// Lỗi không ném ra mà trả về [PipelineResult] với `success=false`,
  /// `errorCode` (`UPLOAD`/`API`/`PIPELINE`) và message kèm tên bước.
  Future<PipelineResult> runFullIdentity(FullIdentityArtifactPaths a) async {
    var stage = 'Chuẩn bị dữ liệu';
    var ocrResult = '';
    try {
      _log('Authorization shape=${EkycAuthHeader.shape(config.accessToken)} '
          'len=${config.accessToken.trim().length}');
      final frontPath = await pickImage(a.frontFullPath, a.frontCropPath);
      final backPath = await pickImage(a.backFullPath, a.backCropPath);
      final farPath = await pickImage(a.farPreviewPath, a.farCropPath);
      final nearPath = await pickImage(a.nearPreviewPath, a.nearCropPath);
      final scanPath = a.scan3dPath;
      if (frontPath.isEmpty) {
        throw VnptApiException('PIPELINE', 'front path required');
      }
      if (farPath.isEmpty || nearPath.isEmpty || scanPath.isEmpty) {
        throw VnptApiException(
            'PIPELINE', 'oval artifacts required for full identity');
      }

      stage = 'Upload ảnh CCCD mặt trước (/file-service/v1/addFile)';
      final frontHash = await uploadFile(frontPath);
      stage = 'Upload ảnh CCCD mặt sau (/file-service/v1/addFile)';
      final backHash = backPath.isEmpty ? null : await uploadFile(backPath);
      stage = 'Upload ảnh khuôn mặt xa (/file-service/v1/addFile)';
      final farHash = await uploadFile(farPath);
      stage = 'Upload ảnh khuôn mặt gần (/file-service/v1/addFile)';
      final nearHash = await uploadFile(nearPath);
      stage = 'Upload dữ liệu 3D (/file-service/v1/addFile)';
      final scanHash = await uploadFile(scanPath);

      final cropParam = (config.isAutoCropParam ||
              frontPath != a.frontFullPath ||
              a.cropParamFront.isEmpty)
          ? '0.0,0.0'
          : a.cropParamFront;
      stage = 'OCR CCCD (/ai/v1/ocr/id)';
      final ocrJson = await ocrId(
        imgFrontHash: frontHash,
        imgBackHash: backHash,
        cropParam: cropParam,
      );
      ocrResult = ocrJson;
      stage = config.checkLivenessFace == 1
          ? 'Liveness 3D (/ai/v1/face/liveness-3d)'
          : 'Liveness 3D (/ai/v1/standard/face/liveness-3d)';
      final livenessJson = await liveness3d(
        farHash: farHash,
        nearHash: nearHash,
        scan3dHash: scanHash,
      );
      return PipelineResult(
        success: true,
        ocrJson: ocrJson,
        liveness3dJson: livenessJson,
      );
    } catch (e) {
      final code = e is VnptApiException ? e.code : 'PIPELINE';
      final msg = e is VnptApiException ? e.message : e.toString();
      return PipelineResult(
        ocrJson: ocrResult,
        errorCode: code,
        errorMessage: 'Bước: $stage\nLỗi: $msg',
      );
    }
  }

  /// Chọn ảnh đầy đủ nếu có, không thì ảnh crop; rỗng nếu không có file hợp lệ.
  @visibleForTesting
  static Future<String> pickImage(String full, String crop) async {
    for (final path in [full, crop]) {
      if (path.isEmpty) continue;
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.file && stat.size > 0) return path;
    }
    return '';
  }

  // ---- Log debug: không bao giờ in credential/hash/định danh -------------

  void _log(String message) {
    if (kDebugMode) debugPrint('[EkycSDK/http] $message');
  }

  /// Dấu vân tay để so sánh giá trị mà không lộ nội dung.
  static String fingerprint(String value) {
    if (value.isEmpty) return '<empty>';
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes).toString().substring(0, 12);
    return '<redacted len=${bytes.length} sha256=$digest>';
  }

  static const _plainFields = {
    'type', 'crop_param', 'step_id', 'file', 'file_content_type', 'title',
    'description',
  };

  void _logRequest(Uri url, Map<String, String> headers, Map<String, Object?> body) {
    if (!kDebugMode) return;
    _log('POST ${url.scheme}://${url.authority}${url.path}');
    url.queryParameters.forEach((k, v) => _log('query.$k=${fingerprint(v)}'));
    final names = headers.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final name in names) {
      final value = headers[name]!;
      final lower = name.toLowerCase();
      if (lower == 'authorization') {
        final i = value.indexOf(' ');
        final scheme = i > 0 ? value.substring(0, i) : '<missing scheme>';
        final cred = i > 0 ? value.substring(i + 1) : value;
        _log('header.$name=$scheme ${fingerprint(cred)}');
      } else if (lower == 'content-type' || lower == 'mac-address') {
        _log('header.$name=$value');
      } else {
        _log('header.$name=${fingerprint(value)}');
      }
    }
    final keys = body.keys.toList()..sort();
    for (final k in keys) {
      final v = '${body[k]}';
      _log('body.$k=${_plainFields.contains(k) ? v : fingerprint(v)}');
    }
  }

  void _logResponse(int status, String text) {
    if (!kDebugMode) return;
    String? message;
    String? logId;
    try {
      final root = jsonDecode(text);
      if (root is Map) {
        message = root['message']?.toString();
        logId = root['logID']?.toString();
      }
    } on FormatException {
      // Không phải JSON: chỉ log status.
    }
    _log('response HTTP $status message=${message ?? '<none>'} '
        'logID=${logId ?? '<none>'}');
  }
}
