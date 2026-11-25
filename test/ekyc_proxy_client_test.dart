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
  tokenId: 'tid',
  tokenKey: 'tkey',
  baseUrl: 'https://host/api/v1/ekyc-proxy',
);

/// Content-Type của part `file` trong body multipart.
String _fileContentType(http.BaseRequest req) {
  final body = latin1.decode((req as http.Request).bodyBytes);
  final m = RegExp(
          r'content-type: ([^\r\n]+)\r\ncontent-disposition: [^\r\n]*name="file"',
          caseSensitive: false)
      .firstMatch(body);
  return m?.group(1) ?? '';
}

EkycProxyClient _client(MockClient mock) =>
    EkycProxyClient(session: _session, deviceId: 'dev', httpClient: mock);

void main() {
  late Directory dir;
  late FaceScanResult scan;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('proxy_test_');
    for (final n in [
      'far.jpg',
      'near.jpg',
      'scan.3dobj',
      'up.JPEG',
      'up.png'
    ]) {
      await File('${dir.path}/$n').writeAsBytes([1, 2, 3]);
    }
    scan = FaceScanResult(
      farImagePath: '${dir.path}/far.jpg',
      farCropPath: '${dir.path}/far.jpg',
      nearImagePath: '${dir.path}/near.jpg',
      nearCropPath: '${dir.path}/near.jpg',
      scan3dPath: '${dir.path}/scan.3dobj',
      faceLogPath: null,
      sessionDir: dir.path,
    );
  });
  tearDown(() => dir.delete(recursive: true));

  test('EkycProxySession.fromJson nối host với proxyBaseUrl', () {
    final s = EkycProxySession.fromJson({
      'sessionId': 'a',
      'clientSession': 'b',
      'sessionToken': 'c',
      'proxyBaseUrl': '/api/v1/ekyc-proxy',
    }, host: 'https://h.com/');
    expect(s.baseUrl, 'https://h.com/api/v1/ekyc-proxy');
  });

  test('verifyFace: upload 3 file → liveness → compare, header đúng', () async {
    final calls = <String>[];
    final fileTypes = <String>[];
    var hashN = 0;
    final client = _client(MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path.endsWith('addFile')) {
        fileTypes.add(_fileContentType(req));
      }
      expect(req.headers['X-Ekyc-Session-Token'], 'tok');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.headers['mac-address'], 'dev');
      if (req.url.path.endsWith('addFile')) {
        return _ok({'hash': 'h${++hashN}'});
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (req.url.path.endsWith('liveness-3d')) {
        expect(body['far_img'], 'h1');
        expect(body['near_img'], 'h2');
        expect(body['scan3d'], 'h3');
        return _ok({'liveness': 'success'});
      }
      expect(body['img_face'], 'h2');
      return _ok({'msg': 'MATCH', 'prob': 99.5});
    }));
    final r = await client.verifyFace(scan, frontHash: 'front');
    expect(calls.where((c) => c.endsWith('addFile')).length, 3);
    expect(fileTypes, ['image/jpeg', 'image/jpeg', 'application/octet-stream']);
    expect(r.liveness.isLive, isTrue);
    expect(r.compare!.isMatch, isTrue);
    expect(r.faceHash, 'h2');
  });

  test('addFile: content type theo đuôi file', () async {
    final types = <String>[];
    final client = _client(MockClient((req) async {
      types.add(_fileContentType(req));
      return _ok({'hash': 'h'});
    }));
    for (final n in ['far.jpg', 'up.JPEG', 'up.png', 'scan.3dobj']) {
      await client.addFile('${dir.path}/$n');
    }
    expect(types, [
      'image/jpeg',
      'image/jpeg',
      'image/png',
      'application/octet-stream',
    ]);
  });

  test('verifyFace: fake_liveness → spoofDetected', () async {
    final client = _client(MockClient((req) async {
      if (req.url.path.endsWith('addFile')) return _ok({'hash': 'h'});
      return _ok({'liveness': 'success', 'fake_liveness': true});
    }));
    expect(
      client.verifyFace(scan),
      throwsA(isA<EkycProxyException>()
          .having((e) => e.code, 'code', EkycProxyException.spoofDetected)),
    );
  });

  test('verifyFace: liveness không đạt → livenessFailed', () async {
    final client = _client(MockClient((req) async {
      if (req.url.path.endsWith('addFile')) return _ok({'hash': 'h'});
      return _ok({'liveness': 'failure'});
    }));
    expect(
      client.verifyFace(scan),
      throwsA(isA<EkycProxyException>()
          .having((e) => e.code, 'code', EkycProxyException.livenessFailed)),
    );
  });

  test('SESSION_NOT_ACTIVE và errors của proxy', () {
    final client = _client(MockClient((_) async => _ok({})));
    expect(
      () => client.parseObject({'code': 'SESSION_NOT_ACTIVE', 'message': 'x'}),
      throwsA(isA<EkycProxyException>()
          .having((e) => e.code, 'code', EkycProxyException.sessionNotActive)),
    );
    expect(
      () => client.parseObject({
        'message': 'IDG-00010003',
        'errors': ['Ảnh kém'],
        'wikex_ekyc': {'passed': false},
      }),
      throwsA(isA<EkycProxyException>()
          .having((e) => e.code, 'code', 'IDG-00010003')
          .having((e) => e.message, 'message', 'Ảnh kém')),
    );
    expect(
      () => client.parseObject({
        'message': 'IDG-00000000',
        'wikex_ekyc': {
          'passed': false,
          'reasons': ['VNPT_ERROR:RECAPTURED_DOCUMENT'],
        },
      }),
      throwsA(isA<EkycProxyException>()
          .having((e) => e.code, 'code', 'RECAPTURED_DOCUMENT')),
    );
  });

  test('verifyCardSide mặt trước: addFile → ocr/front → card/liveness',
      () async {
    final paths = <String>[];
    final fileTypes = <String>[];
    final client = _client(MockClient((req) async {
      paths.add(req.url.path);
      if (req.url.path.endsWith('addFile')) {
        fileTypes.add(_fileContentType(req));
        return _ok({'hash': 'hc'});
      }
      if (req.url.path.endsWith('card/liveness')) {
        return _ok({'liveness': 'success'});
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['img_front'], 'hc');
      expect(body['validate_postcode'], true);
      return _ok({'id': '0123'});
    }));
    final card = CardScanResult(
      side: VnptCardSide.front,
      fullImagePath: scan.farImagePath,
      cropImagePath: scan.farImagePath,
      cropParam: '0.1,0.1',
      sessionDir: dir.path,
    );
    final r = await client.verifyCardSide(card);
    expect(r.ocr['id'], '0123');
    expect(fileTypes, ['image/jpeg']);
    expect(paths.last, endsWith('card/liveness'));
  });

  test('card/liveness từ chối → cardNotGenuine', () async {
    final client = _client(MockClient(
        (_) async => _ok({'liveness': 'failure', 'liveness_msg': 'fake'})));
    expect(
      client.checkCardLiveness('h'),
      throwsA(isA<EkycProxyException>()
          .having((e) => e.code, 'code', EkycProxyException.cardNotGenuine)),
    );
  });
}
