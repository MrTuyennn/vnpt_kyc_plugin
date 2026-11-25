import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _ok(Map<String, Object?> object) => http.Response(
      jsonEncode({
        'message': 'IDG-00000000',
        'wikex_ekyc': {'passed': true},
        'object': object,
      }),
      200,
      headers: _json,
    );

const _session = EkycProxySession(
  sessionId: 'sid',
  clientSession: 'cs',
  sessionToken: 'tok',
  baseUrl: 'https://host/api/v1/ekyc-proxy',
);

void main() {
  late Directory dir;
  late CardScanResult frontScan;
  late CardScanResult backScan;
  late FaceScanResult faceScan;
  late List<String> calls;
  late String compareMsg;
  late bool expire;

  EkycIdentityVerifier build() => EkycIdentityVerifier(EkycProxyClient(
        session: _session,
        deviceId: 'dev',
        httpClient: MockClient((req) async {
          final path = req.url.path.replaceFirst('/api/v1/ekyc-proxy/', '');
          calls.add(path);
          if (expire && path == 'ai/v1/ocr/id') {
            return http.Response(
                jsonEncode({'code': 'SESSION_NOT_ACTIVE', 'message': 'done'}),
                200,
                headers: _json);
          }
          if (path.endsWith('addFile')) return _ok({'hash': 'h${calls.length}'});
          if (path.endsWith('liveness-3d') || path.endsWith('card/liveness')) {
            return _ok({'liveness': 'success'});
          }
          if (path.endsWith('face/compare')) {
            return _ok({'msg': compareMsg, 'prob': 90});
          }
          return _ok({'id': '1'});
        }),
      ));

  setUp(() async {
    calls = [];
    compareMsg = 'MATCH';
    expire = false;
    dir = await Directory.systemTemp.createTemp('verifier_');
    final file = '${dir.path}/img';
    await File(file).writeAsBytes([1]);
    CardScanResult card(VnptCardSide side) => CardScanResult(
        side: side,
        fullImagePath: file,
        cropImagePath: file,
        cropParam: '0,0',
        sessionDir: dir.path);
    frontScan = card(VnptCardSide.front);
    backScan = card(VnptCardSide.back);
    faceScan = FaceScanResult(
        farImagePath: file,
        farCropPath: file,
        nearImagePath: file,
        nearCropPath: file,
        scan3dPath: file,
        faceLogPath: null,
        sessionDir: dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  test('đủ mặt trước, sau, face → cặp + compare → canContinue', () async {
    final v = build();
    await Future.wait([v.submitFront(frontScan), v.submitBack(backScan)]);
    expect(v.pair.isSuccess, isTrue);
    expect(v.canContinue, isFalse);
    await v.submitFace(faceScan);
    expect(v.compare.value!.isMatch, isTrue);
    expect(v.canContinue, isTrue);
    expect(calls.where((c) => c == 'ai/v1/ocr/id').length, 1);
  });

  test('compare không khớp → không cho tiếp tục', () async {
    compareMsg = 'NOMATCH';
    final v = build();
    await v.submitFront(frontScan);
    await v.submitBack(backScan);
    await v.submitFace(faceScan);
    expect(v.compare.isSuccess, isTrue);
    expect(v.canContinue, isFalse);
  });

  test('chụp lại face chỉ chạy lại compare, không chạy lại cặp', () async {
    final v = build();
    await v.submitFront(frontScan);
    await v.submitBack(backScan);
    await v.submitFace(faceScan);
    calls.clear();
    await v.submitFace(faceScan);
    expect(calls.contains('ai/v1/ocr/id'), isFalse);
    expect(calls.where((c) => c == 'ai/v1/face/compare').length, 1);
    expect(v.canContinue, isTrue);
  });

  test('chụp lại mặt trước chạy lại cặp và compare', () async {
    final v = build();
    await v.submitFront(frontScan);
    await v.submitBack(backScan);
    await v.submitFace(faceScan);
    calls.clear();
    await v.submitFront(frontScan);
    expect(calls.contains('ai/v1/ocr/id'), isTrue);
    expect(calls.contains('ai/v1/face/compare'), isTrue);
    expect(v.canContinue, isTrue);
  });

  test('SESSION_NOT_ACTIVE xoá hết kết quả', () async {
    expire = true;
    final v = build();
    await v.submitFront(frontScan);
    await v.submitBack(backScan);
    expect(v.sessionExpired, isTrue);
    expect(v.front.status, IdentityStepStatus.idle);
    expect(v.canContinue, isFalse);
  });
}
