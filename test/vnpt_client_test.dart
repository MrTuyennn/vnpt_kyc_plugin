import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vnpt_kyc_plugin/src/api/auth_header.dart';
import 'package:vnpt_kyc_plugin/src/api/client_session.dart';
import 'package:vnpt_kyc_plugin/src/api/vnpt_client.dart';
import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

class _Call {
  _Call(this.method, this.url, this.headers, this.body);
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;
  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

EkycConfig _cfg({
  String access = 'Bearer eyJabc',
  String flow = '',
  int step = 0,
  int liveness = 2,
  bool autoCrop = false,
}) =>
    EkycConfig(
      accessToken: access,
      tokenId: '"tid"',
      tokenKey: ' tkey ',
      challengeCode: '11111',
      baseUrl: 'https://api.test/',
      documentType: -1,
      flowEkyc: flow,
      stepId: step,
      checkLivenessFace: liveness,
      isAutoCropParam: autoCrop,
    );

/// Dựng client + danh sách request đã ghi lại. [handler] có thể ghi đè phản hồi.
(VnptClient, List<_Call>) _client(
  EkycConfig config, {
  http.Response? Function(_Call call)? handler,
}) {
  final calls = <_Call>[];
  var n = 0;
  final mock = MockClient((req) async {
    final call = _Call(req.method, req.url, req.headers, req.body);
    calls.add(call);
    final custom = handler?.call(call);
    if (custom != null) return custom;
    if (req.url.path.endsWith('/addFile')) {
      return http.Response('{"object":{"hash":"hash${++n}"}}', 200);
    }
    return http.Response('{"message":"IDG-00000000","object":{}}', 200);
  });
  return (
    VnptClient(config: config, clientSession: 'SESSION', httpClient: mock),
    calls
  );
}

Future<FullIdentityArtifactPaths> _files(Directory d,
    {bool back = true, String cropParam = '0.3,0.3'}) async {
  Future<String> f(String name, [String content = 'x']) async {
    final path = '${d.path}/$name';
    await File(path).writeAsString(content);
    return path;
  }

  return FullIdentityArtifactPaths(
    frontFullPath: await f('front.jpg'),
    backFullPath: back ? await f('back.jpg') : '',
    farPreviewPath: await f('far_portrait_preview.jpg'),
    nearPreviewPath: await f('near_portrait_preview.jpg'),
    scan3dPath: await f('3DFace_portrait.3dobj', 'scan|cap'),
    cropParamFront: cropParam,
  );
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('vnpt_client_'));
  tearDown(() => dir.delete(recursive: true));

  group('auth header', () {
    test('thêm Bearer cho JWT trần, không double Bearer', () {
      expect(EkycAuthHeader.authorization('eyJabc'), 'Bearer eyJabc');
      expect(EkycAuthHeader.authorization('Bearer Bearer eyJabc'),
          'Bearer eyJabc');
      expect(EkycAuthHeader.authorization(' "bearer  eyJabc" '),
          'bearer eyJabc');
      expect(EkycAuthHeader.authorization('{"a":1}'), '{"a":1}');
      expect(EkycAuthHeader.authorization('opaque'), 'opaque');
      expect(EkycAuthHeader.authorization(''), '');
    });
  });

  test('client_session Android và iOS', () {
    final android = NativeDeviceInfo(
        platform: 'ANDROID',
        model: 'Pixel',
        osVersion: '34',
        isSimulator: false,
        deviceId: 'aid',
        appId: 'com.app');
    expect(
        buildClientSession(
            device: android,
            sdkVersionLabel: '3.7.4',
            override: '',
            timestampMs: 5),
        'ANDROID_Pixel_34_Device_3.7.4_aid_5_com.app');
    final ios = NativeDeviceInfo(
        platform: 'IOS',
        model: 'iPhone',
        osVersion: '17.2',
        isSimulator: true,
        deviceId: 'idfv',
        appId: 'b.id');
    expect(
        buildClientSession(
            device: ios, sdkVersionLabel: '3.7.4', override: '', timestampMs: 9),
        'IOS_iPhone_ios17.2_Simulator_3.7.4_idfv_9_b.id');
    expect(
        buildClientSession(
            device: ios,
            sdkVersionLabel: 'x',
            override: 'FIXED',
            timestampMs: 1),
        'FIXED');
  });

  group('uploadFile', () {
    test('multipart: URL, header, mime ảnh và mime 3D', () async {
      final (client, calls) = _client(_cfg());
      final paths = await _files(dir);
      expect(await client.uploadFile(paths.frontFullPath), 'hash1');
      expect(await client.uploadFile(paths.scan3dPath), 'hash2');

      final c = calls.first;
      expect(c.method, 'POST');
      expect(c.url.toString(), 'https://api.test/file-service/v1/addFile');
      expect(c.headers['Authorization'], 'Bearer eyJabc');
      expect(c.headers['token-id'], 'tid');
      expect(c.headers['token-key'], 'tkey');
      expect(c.headers['Vnpt-Token'], '8928skjhfa89298jahga1771vbvb');
      expect(c.headers['Content-Type'], startsWith('multipart/form-data'));
      expect(c.headers.containsKey('mac-address'), false);
      expect(c.body, contains('name="file"; filename="front.jpg"'));
      expect(c.body.toLowerCase(), contains('content-type: image/jpeg'));
      expect(c.body, contains('name="title"'));
      expect(c.body, contains('name="description"'));
      expect(calls[1].body.toLowerCase(), contains('content-type: text/plain'));
    });

    test('thiếu file → UPLOAD', () async {
      final (client, _) = _client(_cfg());
      expect(
          () => client.uploadFile('${dir.path}/none.jpg'),
          throwsA(isA<VnptApiException>()
              .having((e) => e.code, 'code', 'UPLOAD')));
    });

    test('Authorization rỗng thì không gửi header', () async {
      final (client, calls) = _client(_cfg(access: '  '));
      await client.uploadFile((await _files(dir)).frontFullPath);
      expect(calls.single.headers.containsKey('Authorization'), false);
    });
  });

  group('OCR', () {
    test('body mặc định (không flow, step 0)', () async {
      final (client, calls) = _client(_cfg());
      await client.ocrId(
          imgFrontHash: 'f', imgBackHash: 'b', cropParam: '0.3,0.3');
      final c = calls.single;
      expect(c.url.toString(), 'https://api.test/ai/v1/ocr/id?challenge_code=11111');
      expect(c.headers['mac-address'], 'TEST1');
      expect(c.headers['Content-Type'], contains('application/json'));
      expect(c.json, {
        'type': -1,
        'img_front': 'f',
        'img_back': 'b',
        'client_session': 'SESSION',
        'token': '8928skjhfa89298jahga1771vbvb',
        'crop_param': '0.3,0.3',
      });
    });

    test('không có mặt sau → bỏ img_back; step_id != 0 không flow', () async {
      final (client, calls) = _client(_cfg(step: 3));
      await client.ocrId(imgFrontHash: 'f', cropParam: '0.0,0.0');
      expect(calls.single.json.containsKey('img_back'), false);
      expect(calls.single.json['step_id'], 3);
      expect(calls.single.json.containsKey('flow'), false);
    });

    test('nhánh flow: có flow + step_id', () async {
      final (client, calls) = _client(_cfg(flow: 'FLOW1', step: 0));
      await client.ocrId(imgFrontHash: 'f', cropParam: 'c');
      expect(calls.single.json['flow'], 'FLOW1');
      expect(calls.single.json['step_id'], 0);
    });
  });

  group('liveness', () {
    test('standard (checkLivenessFace=2), không flow: token + step_id', () async {
      final (client, calls) = _client(_cfg());
      await client.liveness3d(farHash: 'a', nearHash: 'b', scan3dHash: 'c');
      final c = calls.single;
      expect(c.url.toString(),
          'https://api.test/ai/v1/standard/face/liveness-3d?challenge_code=11111');
      expect(c.json, {
        'far_img': 'a',
        'near_img': 'b',
        'scan3d': 'c',
        'client_session': 'SESSION',
        'token': '8928skjhfa89298jahga1771vbvb',
        'step_id': 0,
      });
    });

    test('iBeta (checkLivenessFace=1) + flow: chỉ flow, không token/step_id',
        () async {
      final (client, calls) = _client(_cfg(liveness: 1, flow: 'F'));
      await client.liveness3d(farHash: 'a', nearHash: 'b', scan3dHash: 'c');
      final c = calls.single;
      expect(c.url.path, '/ai/v1/face/liveness-3d');
      expect(c.json['flow'], 'F');
      expect(c.json.containsKey('token'), false);
      expect(c.json.containsKey('step_id'), false);
    });
  });

  group('runFullIdentity', () {
    test('thành công: 5 upload + OCR + liveness theo đúng thứ tự', () async {
      final (client, calls) = _client(_cfg());
      final r = await client.runFullIdentity(await _files(dir));
      expect(r.success, true);
      expect(calls.map((c) => c.url.path).toList(), [
        '/file-service/v1/addFile',
        '/file-service/v1/addFile',
        '/file-service/v1/addFile',
        '/file-service/v1/addFile',
        '/file-service/v1/addFile',
        '/ai/v1/ocr/id',
        '/ai/v1/standard/face/liveness-3d',
      ]);
      // hash theo thứ tự upload: front, back, far, near, scan
      expect(calls[5].json['img_front'], 'hash1');
      expect(calls[5].json['img_back'], 'hash2');
      expect(calls[5].json['crop_param'], '0.3,0.3');
      expect(calls[6].json['far_img'], 'hash3');
      expect(calls[6].json['near_img'], 'hash4');
      expect(calls[6].json['scan3d'], 'hash5');
    });

    test('isAutoCropParam hoặc không có cropParam → 0.0,0.0', () async {
      final (c1, calls1) = _client(_cfg(autoCrop: true));
      await c1.runFullIdentity(await _files(dir));
      expect(calls1[5].json['crop_param'], '0.0,0.0');
      final (c2, calls2) = _client(_cfg());
      await c2.runFullIdentity(await _files(dir, cropParam: ''));
      expect(calls2[5].json['crop_param'], '0.0,0.0');
    });

    test('dùng ảnh crop khi ảnh full không có → crop_param 0.0,0.0', () async {
      final (client, calls) = _client(_cfg());
      final p = await _files(dir);
      await File(p.frontFullPath).delete();
      p.frontCropPath = '${dir.path}/front_crop.jpg';
      await File(p.frontCropPath).writeAsString('y');
      await client.runFullIdentity(p);
      expect(calls[0].body, contains('filename="front_crop.jpg"'));
      expect(calls[5].json['crop_param'], '0.0,0.0');
    });

    test('thiếu mặt sau: bỏ qua upload + img_back', () async {
      final (client, calls) = _client(_cfg());
      final r = await client.runFullIdentity(await _files(dir, back: false));
      expect(r.success, true);
      expect(calls.where((c) => c.url.path.endsWith('addFile')).length, 4);
      expect(calls[4].json.containsKey('img_back'), false);
    });

    test('HTTP lỗi khi upload → UPLOAD kèm tên bước', () async {
      final (client, calls) = _client(_cfg(),
          handler: (c) => c.url.path.endsWith('addFile')
              ? http.Response('forbidden', 403)
              : http.Response('{}', 200));
      final r = await client.runFullIdentity(await _files(dir));
      expect(r.success, false);
      expect(r.errorCode, 'UPLOAD');
      expect(r.errorMessage,
          'Bước: Upload ảnh CCCD mặt trước (/file-service/v1/addFile)\nLỗi: HTTP 403: forbidden');
      expect(calls.length, 1);
    });

    test('HTTP lỗi ở liveness → API, giữ lại ocrJson', () async {
      final (client, _) = _client(_cfg(liveness: 1),
          handler: (c) => c.url.path.contains('liveness')
              ? http.Response('boom', 500)
              : null);
      final r = await client.runFullIdentity(await _files(dir));
      expect(r.errorCode, 'API');
      expect(r.errorMessage,
          'Bước: Liveness 3D (/ai/v1/face/liveness-3d)\nLỗi: HTTP 500: boom');
      expect(r.ocrJson, contains('IDG-00000000'));
    });

    test('lỗi ở OCR → API, bước OCR', () async {
      final (client, _) = _client(_cfg(),
          handler: (c) =>
              c.url.path.endsWith('/ocr/id') ? http.Response('x', 401) : null);
      final r = await client.runFullIdentity(await _files(dir));
      expect(r.errorCode, 'API');
      expect(r.errorMessage, startsWith('Bước: OCR CCCD (/ai/v1/ocr/id)'));
      expect(r.ocrJson, '');
    });

    test('upload trả về không có hash → UPLOAD', () async {
      final (client, _) = _client(_cfg(),
          handler: (c) => c.url.path.endsWith('addFile')
              ? http.Response('{"object":{}}', 200)
              : null);
      final r = await client.runFullIdentity(await _files(dir));
      expect(r.errorCode, 'UPLOAD');
      expect(r.errorMessage, contains('No hash in response'));
    });

    test('thiếu ảnh mặt trước → PIPELINE', () async {
      final (client, calls) = _client(_cfg());
      final r = await client.runFullIdentity(FullIdentityArtifactPaths());
      expect(r.errorCode, 'PIPELINE');
      expect(r.errorMessage,
          'Bước: Chuẩn bị dữ liệu\nLỗi: front path required');
      expect(calls, isEmpty);
    });

    test('lỗi mạng → PIPELINE (như OkHttp IOException)', () async {
      final client = VnptClient(
          config: _cfg(),
          clientSession: 's',
          httpClient: MockClient((_) async => throw http.ClientException('down')));
      final r = await client.runFullIdentity(await _files(dir));
      expect(r.success, false);
      expect(r.errorCode, 'PIPELINE');
      expect(r.errorMessage, contains('down'));
    });
  });

  test('fingerprint không lộ giá trị gốc', () {
    final f = VnptClient.fingerprint('secret-token');
    expect(f, isNot(contains('secret')));
    expect(f, contains('len=12'));
    expect(VnptClient.fingerprint(''), '<empty>');
  });

  test('MessageResult dùng chung (sanity)', () {
    expect(MessageResult.cardValid, 20);
  });
}
