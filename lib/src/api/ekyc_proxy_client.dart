import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:vnpt_kyc_plugin/src/api/ekyc_file_limits.dart';
import 'package:vnpt_kyc_plugin/src/flow/scan_results.dart';

/// Phiên eKYC do backend cấp (`POST sessions/init`): dùng token của phiên để gọi
/// proxy VNPT thay vì token VNPT trực tiếp.
class EkycProxySession {
  const EkycProxySession({
    required this.sessionId,
    required this.clientSession,
    required this.sessionToken,
    required this.baseUrl,
    this.tokenId = '',
    this.tokenKey = '',
  });

  /// Dựng từ response `sessions/init`. [host] là domain backend; URL proxy là
  /// `host + proxyBaseUrl`.
  factory EkycProxySession.fromJson(
    Map<String, dynamic> json, {
    required String host,
  }) {
    String text(String key) => (json[key] as String?)?.trim() ?? '';
    final base = host.replaceAll(RegExp(r'/+$'), '');
    return EkycProxySession(
      sessionId: text('sessionId'),
      clientSession: text('clientSession'),
      sessionToken: text('sessionToken'),
      tokenId: text('tokenId'),
      tokenKey: text('tokenKey'),
      baseUrl: '$base${text('proxyBaseUrl')}',
    );
  }

  final String sessionId;
  final String clientSession;
  final String sessionToken;
  final String tokenId;
  final String tokenKey;

  /// URL gốc của proxy, ví dụ `https://host/api/v1/ekyc-proxy`.
  final String baseUrl;
}

/// Lỗi gọi proxy. [code] là mã `IDG-…`, lý do của proxy (ví dụ
/// `RECAPTURED_DOCUMENT`) hoặc một trong các hằng bên dưới.
class EkycProxyException implements Exception {
  EkycProxyException(this.message, {this.code});

  /// Phiên đã `COMPLETED` hoặc hết hạn: phải tạo phiên mới và làm lại.
  static const sessionNotActive = 'SESSION_NOT_ACTIVE';

  /// Giấy tờ bị `card/liveness` từ chối.
  static const cardNotGenuine = 'CARD_NOT_GENUINE';

  /// Khuôn mặt bị nghi giả mạo (face swapping / fake liveness).
  static const spoofDetected = 'SPOOF_DETECTED';

  /// Liveness 3D không đạt.
  static const livenessFailed = 'LIVENESS_FAILED';

  /// File vượt [ekycMaxImageBytes] (hoặc `maxFileBytes` truyền vào).
  static const fileTooLarge = 'FILE_TOO_LARGE';

  /// Mất kết nối, timeout hoặc server trả 5xx.
  static const network = 'NETWORK';

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$message [$code]';
}

/// Kết quả `face/compare`.
class FaceCompareResult {
  const FaceCompareResult({required this.msg, required this.prob});

  final String msg;
  final double prob;

  bool get isMatch => msg == 'MATCH';
}

/// Kết quả liveness 3D (`object` của response).
class FaceLivenessResult {
  const FaceLivenessResult({
    required this.isLive,
    required this.faceSwapping,
    required this.fakeLiveness,
    required this.raw,
  });

  final bool isLive;
  final bool faceSwapping;
  final bool fakeLiveness;
  final Map<String, dynamic> raw;
}

/// Kết quả xác thực khuôn mặt (upload + liveness, và so khớp nếu có ảnh CCCD).
class FaceVerifyResult {
  const FaceVerifyResult({
    required this.liveness,
    required this.farHash,
    required this.nearHash,
    required this.scan3dHash,
    this.compare,
  });

  final FaceLivenessResult liveness;
  final String farHash;
  final String nearHash;
  final String scan3dHash;

  /// `null` nếu không truyền `frontHash`.
  final FaceCompareResult? compare;

  /// Hash ảnh chân dung dùng để so khớp (ảnh gần).
  String get faceHash => nearHash;
}

/// Kết quả upload + OCR một mặt CCCD.
class CardVerifyResult {
  const CardVerifyResult({
    required this.side,
    required this.hash,
    required this.ocr,
  });

  final VnptCardSide side;
  final String hash;

  /// `object` của response OCR một mặt.
  final Map<String, dynamic> ocr;
}

/// Client gọi proxy VNPT của backend (token theo phiên eKYC).
///
/// Port từ `EkycDatasource` của app Wikex: header, cách đọc `wikex_ekyc`,
/// `errors`, `SESSION_NOT_ACTIVE` giữ nguyên. Mọi lỗi ném [EkycProxyException].
class EkycProxyClient {
  EkycProxyClient({
    required this.session,
    required this.deviceId,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
    this.maxFileBytes = ekycMaxImageBytes,
  }) : _http = httpClient ?? http.Client();

  static const _okMessage = 'IDG-00000000';
  static const _sessionHeader = 'X-Ekyc-Session-Token';

  final EkycProxySession session;

  /// Gửi trong header `mac-address`.
  final String deviceId;
  final Duration timeout;

  /// Giới hạn dung lượng mỗi file upload; `null` để tắt kiểm tra.
  final int? maxFileBytes;
  final http.Client _http;

  String get _base => session.baseUrl.replaceAll(RegExp(r'/+$'), '');

  void close() => _http.close();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${session.sessionToken}',
        _sessionHeader: session.sessionToken,
        if (session.tokenId.isNotEmpty) 'Token-id': session.tokenId,
        if (session.tokenKey.isNotEmpty) 'Token-key': session.tokenKey,
        'mac-address': deviceId,
      };

  // ---- API đơn lẻ ----------------------------------------------------------

  /// `POST file-service/v1/addFile` → `hash`.
  Future<String> addFile(
    String path, {
    String? title,
    String? description,
  }) async {
    final limit = maxFileBytes;
    if (limit != null && await isEkycFileTooLarge(path, maxBytes: limit)) {
      throw EkycProxyException(
        'File exceeds $limit bytes: ${p.basename(path)}',
        code: EkycProxyException.fileTooLarge,
      );
    }
    final name = p.basename(path);
    final stem = p.basenameWithoutExtension(path);
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/file-service/v1/addFile'),
    )
      ..headers.addAll(_headers)
      ..fields['title'] = title ?? stem
      ..fields['description'] = description ?? stem
      ..fields['challengeCode'] = session.sessionId
      ..files
          .add(await http.MultipartFile.fromPath('file', path, filename: name));
    final object = _object(await _send(req));
    return object['hash'] as String? ?? '';
  }

  /// `POST ai/v1/ocr/id/front|back` → `object`. Mặt trước gửi thêm
  /// `validate_postcode`.
  Future<Map<String, dynamic>> ocrCard({
    required bool front,
    required String hash,
    String cropParam = '0,0',
  }) async {
    final body = front
        ? {
            'img_front': hash,
            'type': -1,
            'validate_postcode': true,
            'crop_param': cropParam,
            'challengeCode': session.sessionId,
          }
        : {
            'img_back': hash,
            'type': -1,
            'challengeCode': session.sessionId,
          };
    return _object(
        await _post(front ? 'ai/v1/ocr/id/front' : 'ai/v1/ocr/id/back', body));
  }

  /// `POST ai/v1/card/liveness`: ném [EkycProxyException.cardNotGenuine] nếu
  /// `object.liveness` khác `success`.
  Future<void> checkCardLiveness(String hash,
      {String cropParam = '0,0'}) async {
    final object = _object(await _post('ai/v1/card/liveness', {
      'img': hash,
      'crop_param': cropParam,
      'challengeCode': session.sessionId,
    }));
    final liveness = object['liveness'];
    if (liveness is String && liveness != 'success') {
      throw EkycProxyException(
        object['liveness_msg']?.toString() ?? 'VNPT: card liveness $liveness',
        code: EkycProxyException.cardNotGenuine,
      );
    }
  }

  /// `POST ai/v1/ocr/id`: đối chiếu cặp hai mặt.
  Future<Map<String, dynamic>> verifyIdCard({
    required String frontHash,
    required String backHash,
    String cropParam = '0,0',
  }) async =>
      _object(await _post('ai/v1/ocr/id', {
        'img_front': frontHash,
        'img_back': backHash,
        'type': -1,
        'validate_postcode': true,
        'crop_param': cropParam,
        'challengeCode': session.sessionId,
      }));

  /// `POST ai/v1/face/compare`.
  Future<FaceCompareResult> compareFace({
    required String frontHash,
    required String faceHash,
  }) async {
    final object = _object(await _post('ai/v1/face/compare', {
      'img_front': frontHash,
      'img_face': faceHash,
      'client_session': session.clientSession,
      'token': session.sessionId,
      'challengeCode': session.sessionId,
    }));
    return FaceCompareResult(
      msg: object['msg'] as String? ?? '',
      prob: (object['prob'] as num?)?.toDouble() ?? 0,
    );
  }

  /// `POST ai/v1/face/liveness-3d` (iBeta). Chưa kiểm chứng đường dẫn trên proxy
  /// Wikex: SDK cũ tự nối đường dẫn này vào `proxyBaseUrl`.
  Future<FaceLivenessResult> faceLiveness3d({
    required String farHash,
    required String nearHash,
    required String scan3dHash,
  }) async {
    final object = _object(await _post('ai/v1/face/liveness-3d', {
      'far_img': farHash,
      'near_img': nearHash,
      'scan3d': scan3dHash,
      'client_session': session.clientSession,
      'token': session.sessionId,
      'challengeCode': session.sessionId,
    }));
    bool flag(Object? v) =>
        v == true || (v is String && v.trim().toLowerCase() == 'true');
    final live = object['liveness'];
    return FaceLivenessResult(
      isLive: flag(live) ||
          (live is String && live.trim().toLowerCase() == 'success'),
      faceSwapping: flag(object['face_swapping']),
      fakeLiveness: flag(object['fake_liveness']),
      raw: object,
    );
  }

  // ---- Luồng ghép ----------------------------------------------------------

  /// Upload ảnh mặt xa, mặt gần, scan 3D → liveness 3D; có [frontHash] thì so
  /// khớp luôn với ảnh gần.
  ///
  /// Ném [EkycProxyException.spoofDetected] nếu face swapping / fake liveness,
  /// [EkycProxyException.livenessFailed] nếu liveness không đạt. Kết quả
  /// `compare` không ném khi không khớp; kiểm tra `compare.isMatch`.
  Future<FaceVerifyResult> verifyFace(
    FaceScanResult scan, {
    String? frontHash,
  }) async {
    final farHash = await addFile(scan.farImagePath);
    final nearHash = await addFile(scan.nearImagePath);
    final scan3dHash = await addFile(scan.scan3dPath);
    final liveness = await faceLiveness3d(
      farHash: farHash,
      nearHash: nearHash,
      scan3dHash: scan3dHash,
    );
    if (liveness.faceSwapping || liveness.fakeLiveness) {
      throw EkycProxyException(
        'Phát hiện dấu hiệu giả mạo khuôn mặt.',
        code: EkycProxyException.spoofDetected,
      );
    }
    if (!liveness.isLive) {
      throw EkycProxyException(
        'Xác thực liveness khuôn mặt không đạt.',
        code: EkycProxyException.livenessFailed,
      );
    }
    final compare = frontHash == null || frontHash.isEmpty
        ? null
        : await compareFace(frontHash: frontHash, faceHash: nearHash);
    return FaceVerifyResult(
      liveness: liveness,
      farHash: farHash,
      nearHash: nearHash,
      scan3dHash: scan3dHash,
      compare: compare,
    );
  }

  /// Upload ảnh crop của một mặt rồi OCR; mặt trước chạy thêm `card/liveness`.
  Future<CardVerifyResult> verifyCardSide(CardScanResult scan) async {
    final front = scan.side == VnptCardSide.front;
    final hash = await addFile(scan.cropImagePath);
    final ocr = await ocrCard(front: front, hash: hash);
    if (front) await checkCardLiveness(hash);
    return CardVerifyResult(side: scan.side, hash: hash, ocr: ocr);
  }

  // ---- HTTP ----------------------------------------------------------------

  Future<dynamic> _post(String path, Map<String, Object?> body) {
    final req = http.Request('POST', Uri.parse('$_base/$path'))
      ..headers.addAll(_headers)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
    return _send(req);
  }

  Future<dynamic> _send(http.BaseRequest req) async {
    final http.Response resp;
    try {
      resp = await http.Response.fromStream(
        await _http.send(req).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw EkycProxyException('Timeout sau ${timeout.inSeconds}s',
          code: EkycProxyException.network);
    } on SocketException catch (e) {
      throw EkycProxyException(e.message, code: EkycProxyException.network);
    } on http.ClientException catch (e) {
      throw EkycProxyException(e.message, code: EkycProxyException.network);
    }
    if (kDebugMode) {
      debugPrint('[EkycSDK/proxy] ${req.method} ${req.url.path} '
          '-> ${resp.statusCode}');
    }
    // 4xx vẫn có body `errors` cần đọc; chỉ 5xx là lỗi hạ tầng.
    if (resp.statusCode >= 500) {
      throw EkycProxyException('HTTP ${resp.statusCode}',
          code: EkycProxyException.network);
    }
    try {
      return jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
    } on FormatException {
      throw EkycProxyException('Invalid VNPT response');
    }
  }

  /// Thành công khi `wikex_ekyc.passed == true` và `errors` rỗng (không có
  /// `wikex_ekyc` thì dựa vào `message`). Trả `object`.
  @visibleForTesting
  Map<String, dynamic> parseObject(Object? data) => _object(data);

  Map<String, dynamic> _object(Object? data) {
    if (data is! Map) throw EkycProxyException('Invalid VNPT response');
    if (data['code'] == EkycProxyException.sessionNotActive) {
      throw EkycProxyException(
        data['message']?.toString() ?? 'Session not active',
        code: EkycProxyException.sessionNotActive,
      );
    }
    final errors = data['errors'] is List
        ? (data['errors'] as List).map((e) => '$e').toList()
        : const <String>[];
    final wikex = data['wikex_ekyc'];
    final passed =
        wikex is Map ? wikex['passed'] == true : data['message'] == _okMessage;
    if (!passed || errors.isNotEmpty) {
      final reasonList = wikex is Map && wikex['reasons'] is List
          ? (wikex['reasons'] as List).map((e) => '$e').toList()
          : const <String>[];
      final reasons = reasonList.join('. ');
      final code = data['message']?.toString() ?? '';
      throw EkycProxyException(
        errors.isNotEmpty
            ? errors.join('. ')
            : reasons.isNotEmpty
                ? reasons
                : 'VNPT: ${data['message']}',
        code: code.startsWith('IDG-') && code != _okMessage
            ? code
            : reasonList.firstOrNull?.replaceFirst('VNPT_ERROR:', ''),
      );
    }
    final object = data['object'];
    if (object is! Map) throw EkycProxyException('Invalid VNPT response');
    return Map<String, dynamic>.from(object);
  }
}
