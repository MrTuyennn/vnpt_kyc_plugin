import 'dart:async';

import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:vnpt_kyc_plugin/src/api/ekyc_proxy_client.dart';
import 'package:vnpt_kyc_plugin/src/flow/scan_results.dart';
import 'package:vnpt_kyc_plugin/src/l10n/ekyc_messages.dart';

/// Trạng thái một bước (mặt trước, mặt sau, khuôn mặt, đối chiếu).
enum IdentityStepStatus { idle, running, success, failure }

class IdentityStep<T> {
  const IdentityStep({
    this.status = IdentityStepStatus.idle,
    this.value,
    this.error,
    this.message,
  });

  final IdentityStepStatus status;
  final T? value;
  final EkycProxyException? error;

  /// Thông báo đã dịch theo ngôn ngữ đang chọn khi bước lỗi (hoặc `compare` không
  /// khớp); `null` nếu không có lỗi.
  final String? message;

  bool get isRunning => status == IdentityStepStatus.running;
  bool get isSuccess => status == IdentityStepStatus.success;
}

/// Điều phối xác minh danh tính qua proxy, theo luồng của app Wikex.
///
/// 1. Mặt trước: `addFile` → `ocr/id/front` → `card/liveness`.
///    Mặt sau: `addFile` → `ocr/id/back`. Hai mặt chạy độc lập, lỗi hiện ở mặt đó.
/// 2. Cả hai OCR thành công → `ocr/id` đối chiếu cặp (lỗi hiện ở [pair]).
/// 3. Khuôn mặt: `addFile` ×3 → `liveness-3d` (lỗi hiện ở [face]).
/// 4. Cặp đạt **và** có ảnh khuôn mặt → `face/compare` với ảnh mặt trước
///    (lỗi hiện ở [compare]).
/// 5. [canContinue] chỉ `true` khi cặp đạt, `compare.isMatch` và đủ ba ảnh.
///
/// Chụp lại mặt trước/sau thì cặp và so khớp chạy lại; chụp lại khuôn mặt thì
/// chỉ so khớp chạy lại. Kết quả của lần gọi cũ bị bỏ qua. `SESSION_NOT_ACTIVE`
/// xoá hết kết quả và bật [sessionExpired]: app cần lấy phiên mới
/// ([replaceClient]) rồi cho người dùng làm lại từ đầu.
class EkycIdentityVerifier extends ChangeNotifier {
  /// [locale] chọn bản dịch dựng sẵn (`vi`, `en`); [messages] ghi đè hoàn toàn
  /// nếu muốn dùng chuỗi riêng. Đổi sau bằng [setLocale] / [setMessages].
  EkycIdentityVerifier(
    this._client, {
    Locale locale = const Locale('vi'),
    EkycMessages? messages,
  }) : _messages = messages ?? EkycMessages.of(locale);

  EkycProxyClient _client;
  EkycMessages _messages;

  EkycMessages get messages => _messages;

  void setLocale(Locale locale) => setMessages(EkycMessages.of(locale));

  void setMessages(EkycMessages messages) {
    _messages = messages;
    notifyListeners();
  }

  IdentityStep<CardVerifyResult> front = const IdentityStep();
  IdentityStep<CardVerifyResult> back = const IdentityStep();
  IdentityStep<void> pair = const IdentityStep();
  IdentityStep<FaceVerifyResult> face = const IdentityStep();
  IdentityStep<FaceCompareResult> compare = const IdentityStep();

  /// `true` khi phiên hết hạn/đã hoàn tất và mọi kết quả đã bị xoá.
  bool sessionExpired = false;

  var _frontSeq = 0;
  var _backSeq = 0;
  var _faceSeq = 0;
  var _pairSeq = 0;
  var _compareSeq = 0;

  bool get canContinue =>
      front.isSuccess &&
      back.isSuccess &&
      face.isSuccess &&
      pair.isSuccess &&
      compare.value?.isMatch == true;

  /// Thông báo khi phiên hết hạn ([sessionExpired]).
  String get sessionExpiredMessage => _messages.sessionExpired;

  /// Dùng phiên mới sau khi [sessionExpired]. Xoá toàn bộ kết quả cũ.
  void replaceClient(EkycProxyClient client) {
    _client.close();
    _client = client;
    reset();
  }

  void reset() {
    _frontSeq++;
    _backSeq++;
    _faceSeq++;
    _pairSeq++;
    _compareSeq++;
    front = back = const IdentityStep();
    pair = const IdentityStep();
    face = const IdentityStep();
    compare = const IdentityStep();
    sessionExpired = false;
    notifyListeners();
  }

  Future<void> submitFront(CardScanResult scan) async {
    final seq = ++_frontSeq;
    front = const IdentityStep(status: IdentityStepStatus.running);
    _invalidatePair();
    notifyListeners();
    final result = await _run(() => _client.verifyCardSide(scan));
    if (seq != _frontSeq) return;
    front = _step(result);
    notifyListeners();
    await _verifyPairIfReady();
    await _compareIfReady();
  }

  Future<void> submitBack(CardScanResult scan) async {
    final seq = ++_backSeq;
    back = const IdentityStep(status: IdentityStepStatus.running);
    _invalidatePair();
    notifyListeners();
    final result = await _run(() => _client.verifyCardSide(scan));
    if (seq != _backSeq) return;
    back = _step(result);
    notifyListeners();
    await _verifyPairIfReady();
  }

  Future<void> submitFace(FaceScanResult scan) async {
    final seq = ++_faceSeq;
    face = const IdentityStep(status: IdentityStepStatus.running);
    compare = const IdentityStep();
    _compareSeq++;
    notifyListeners();
    final result = await _run(() => _client.verifyFace(scan));
    if (seq != _faceSeq) return;
    // Liveness lỗi khi làm lại: bỏ ảnh/hash/compare cũ (đã xoá ở trên).
    face = _step(result);
    notifyListeners();
    await _compareIfReady();
  }

  // Cặp phụ thuộc cả hai mặt nên mọi lần chụp lại đều làm kết quả cũ mất hiệu lực.
  void _invalidatePair() {
    _pairSeq++;
    _compareSeq++;
    pair = const IdentityStep();
    compare = const IdentityStep();
  }

  Future<void> _verifyPairIfReady() async {
    final f = front.value;
    final b = back.value;
    if (f == null || b == null || !front.isSuccess || !back.isSuccess) return;
    final seq = ++_pairSeq;
    pair = const IdentityStep(status: IdentityStepStatus.running);
    notifyListeners();
    final result = await _run(
      () => _client.verifyIdCard(frontHash: f.hash, backHash: b.hash),
    );
    if (seq != _pairSeq) return;
    pair = result.error != null
        ? _failure<void>(result.error!)
        : const IdentityStep(status: IdentityStepStatus.success);
    notifyListeners();
    await _compareIfReady();
  }

  Future<void> _compareIfReady() async {
    final f = front.value;
    final v = face.value;
    if (!pair.isSuccess || f == null || v == null || !face.isSuccess) return;
    final seq = ++_compareSeq;
    compare = const IdentityStep(status: IdentityStepStatus.running);
    notifyListeners();
    final result = await _run(
      () => _client.compareFace(frontHash: f.hash, faceHash: v.faceHash),
    );
    if (seq != _compareSeq) return;
    compare = _step(result);
    final matched = result.value;
    if (matched != null && !matched.isMatch) {
      compare = IdentityStep<FaceCompareResult>(
        status: IdentityStepStatus.success,
        value: matched,
        message: _messages.faceMismatch,
      );
    }
    notifyListeners();
  }

  Future<_Outcome<T>> _run<T>(Future<T> Function() call) async {
    try {
      return _Outcome(value: await call());
    } on EkycProxyException catch (e) {
      if (e.code == EkycProxyException.sessionNotActive) _expire();
      return _Outcome(error: e);
    }
  }

  IdentityStep<T> _failure<T>(EkycProxyException e) => IdentityStep<T>(
        status: IdentityStepStatus.failure,
        error: e,
        message: _messages.forError(e),
      );

  IdentityStep<T> _step<T>(_Outcome<T> r) => r.error != null
      ? _failure<T>(r.error!)
      : IdentityStep<T>(status: IdentityStepStatus.success, value: r.value);

  void _expire() {
    _frontSeq++;
    _backSeq++;
    _faceSeq++;
    _pairSeq++;
    _compareSeq++;
    front = back = const IdentityStep();
    pair = const IdentityStep();
    face = const IdentityStep();
    compare = const IdentityStep();
    sessionExpired = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _Outcome<T> {
  const _Outcome({this.value, this.error});

  final T? value;
  final EkycProxyException? error;
}
