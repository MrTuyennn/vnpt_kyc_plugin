import 'dart:convert';

import 'package:vnpt_kyc_plugin/src/core/pipeline_models.dart';

Map<String, dynamic>? vnptResponseObject(String raw) {
  final object = _jsonMap(raw)?['object'];
  return object is Map<String, dynamic> ? object : null;
}

bool vnptOcrAccepted(String raw) {
  final root = _jsonMap(raw);
  final object = vnptResponseObject(raw);
  return _acceptedEnvelope(root) &&
      object != null &&
      _hasText(object['id']) &&
      _hasText(object['name']);
}

bool vnptLivenessAccepted(String raw) {
  final root = _jsonMap(raw);
  final object = vnptResponseObject(raw);
  if (!_acceptedEnvelope(root) || object == null) return false;

  if (_trueValue(object['fake_liveness']) ||
      _trueValue(object['face_swapping'])) {
    return false;
  }
  final result = object['liveness'];
  return _trueValue(result) ||
      (result is String && result.trim().toLowerCase() == 'success');
}

/// Native transport returns HTTP success. Require a successful decision from
/// both VNPT responses before reporting identity verification as complete.
PipelineResult verifyVnptIdentity(PipelineResult result) {
  if (!result.success) return result;
  final ocrOk = vnptOcrAccepted(result.ocrJson);
  final livenessOk = vnptLivenessAccepted(result.liveness3dJson);
  if (ocrOk && livenessOk) return result;
  return PipelineResult(
    ocrJson: result.ocrJson,
    liveness3dJson: result.liveness3dJson,
    errorCode: ocrOk ? 'LIVENESS' : 'OCR',
    errorMessage: ocrOk
        ? 'VNPT chưa xác nhận khuôn mặt. Hãy thử xác thực lại.'
        : 'VNPT chưa trả về đủ thông tin CCCD. Hãy kiểm tra lại ảnh hai mặt.',
  );
}

Map<String, dynamic>? _jsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

bool _acceptedEnvelope(Map<String, dynamic>? root) {
  if (root == null || root['success'] == false || _hasText(root['error'])) {
    return false;
  }
  final message = root['message']?.toString().trim().toLowerCase();
  return message == 'idg-00000000' || message == 'success';
}

bool _hasText(Object? value) =>
    value != null && value.toString().trim().isNotEmpty;

bool _trueValue(Object? value) =>
    value == true || (value is String && value.trim().toLowerCase() == 'true');
