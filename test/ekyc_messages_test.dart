import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _session = EkycProxySession(
  sessionId: 's',
  clientSession: 'c',
  sessionToken: 't',
  baseUrl: 'https://h/p',
);

void main() {
  test('EkycMessages.of chọn bản dịch theo locale', () {
    expect(EkycMessages.of(const Locale('en')), same(EkycMessages.en));
    expect(EkycMessages.of(const Locale('vi')), same(EkycMessages.vi));
    expect(EkycMessages.of(const Locale('fr')), same(EkycMessages.vi));
  });

  test('forError map mã, phân biệt IDG-00010003, fallback message gốc', () {
    const m = EkycMessages.en;
    expect(m.forError(EkycProxyException('x', code: 'IDG-00010003')),
        m.imageQuality);
    expect(
        m.forError(EkycProxyException('khong cung loai', code: 'IDG-00010003')),
        m.frontBackMismatch);
    expect(m.forError(EkycProxyException('x', code: 'RECAPTURED_DOCUMENT')),
        m.recaptured);
    expect(
        m.forError(EkycProxyException('x', code: EkycProxyException.network)),
        m.networkError);
    expect(m.forError(EkycProxyException('raw server text', code: 'UNKNOWN')),
        'raw server text');
  });

  test('copyWith cho phép truyền chuỗi riêng', () {
    final m = EkycMessages.vi.copyWith(faceMismatch: 'custom');
    expect(m.faceMismatch, 'custom');
    expect(m.busy, EkycMessages.vi.busy);
  });

  test('isEkycFileTooLarge và addFile chặn file quá giới hạn', () async {
    final dir = await Directory.systemTemp.createTemp('limit_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/big.jpg')
      ..writeAsBytesSync(List.filled(10, 1));
    expect(await isEkycFileTooLarge(file.path, maxBytes: 5), isTrue);
    expect(await isEkycFileTooLarge(file.path), isFalse);
    final api = EkycProxyClient(
      session: _session,
      deviceId: 'd',
      maxFileBytes: 5,
      httpClient: MockClient((_) async => fail('không được gọi mạng')),
    );
    expect(
      api.addFile(file.path),
      throwsA(isA<EkycProxyException>()
          .having((e) => e.code, 'code', EkycProxyException.fileTooLarge)),
    );
  });

  test('verifier trả thông báo đã dịch theo locale truyền vào', () async {
    final dir = await Directory.systemTemp.createTemp('verifier_msg_');
    addTearDown(() => dir.delete(recursive: true));
    final img = '${dir.path}/i.jpg';
    File(img).writeAsBytesSync([1]);
    final api = EkycProxyClient(
      session: _session,
      deviceId: 'd',
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('addFile')) {
          return http.Response(
              jsonEncode({
                'message': 'IDG-00000000',
                'wikex_ekyc': {'passed': true},
                'object': {'hash': 'h'},
              }),
              200,
              headers: _json);
        }
        return http.Response(
            jsonEncode({
              'message': 'IDG-00010004',
              'errors': ['busy'],
              'wikex_ekyc': {'passed': false},
            }),
            200,
            headers: _json);
      }),
    );
    final verifier = EkycIdentityVerifier(api, locale: const Locale('en'));
    final scan = CardScanResult(
      side: VnptCardSide.front,
      fullImagePath: img,
      cropImagePath: img,
      cropParam: '0,0',
      sessionDir: dir.path,
    );
    await verifier.submitFront(scan);
    expect(verifier.front.message, EkycMessages.en.busy);
    verifier.setLocale(const Locale('vi'));
    await verifier.submitFront(scan);
    expect(verifier.front.message, EkycMessages.vi.busy);
  });
}
