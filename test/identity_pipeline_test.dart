import 'dart:io';

import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _ocr = '''
{"message":"IDG-00000000","object":{"id":"000000000000","name":"Người thử nghiệm"}}
''';

class _Device extends EkycDeviceApi {
  @override
  Future<NativeDeviceInfo> deviceInfo() async => NativeDeviceInfo(
      platform: 'ANDROID',
      model: 'Pixel',
      osVersion: '34',
      isSimulator: false,
      deviceId: 'dev',
      appId: 'com.example');
}

const _utf8 = {'content-type': 'application/json; charset=utf-8'};

/// Server giả: addFile -> hash, OCR và liveness trả về JSON cho trước.
class _Server {
  _Server(this.liveness);

  final String liveness;
  int calls = 0;

  http.Client get client => MockClient((req) async {
        calls++;
        final path = req.url.path;
        if (path.endsWith('/addFile')) {
          return http.Response('{"object":{"hash":"h$calls"}}', 200);
        }
        if (path.endsWith('/ocr/id'))
          return http.Response(_ocr, 200, headers: _utf8);
        return http.Response(liveness, 200, headers: _utf8);
      });
}

EkycConfig _config() =>
    EkycConfig(accessToken: 'eyJabc', tokenId: 'id', tokenKey: 'key');

EkycCore _core(_Server server, {EkycNativeEngine? engine}) => EkycCore(
    engine: engine ?? _CardEngine(),
    deviceApi: _Device(),
    httpClient: server.client);

class _CardEngine extends EkycNativeEngine {
  int quality = 27;
  bool? isFront;

  @override
  Future<void> configure(NativeEngineConfig config) async {}

  @override
  Future<int> cardValidateV2(Uint8List jpeg, bool front) async {
    isFront = front;
    expect(jpeg, [3, 4]);
    return quality;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'rejected still never commits the card, accepted still stores both files',
      () async {
    final dir = await Directory.systemTemp.createTemp();
    const provider = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(provider, (_) async => dir.path);
    addTearDown(() async {
      messenger.setMockMethodCallHandler(provider, null);
      await dir.delete(recursive: true);
    });
    final engine = _CardEngine();
    final core = EkycCore(engine: engine);
    final artifacts = await core.startSession();
    final full = Uint8List.fromList([1, 2]);
    final crop = Uint8List.fromList([3, 4]);
    Future<int> capture() => core.commitCardCapture(
          full,
          isFront: false,
          guideJpeg: crop,
          cropParam: '0.30,0.30',
        );
    expect(await capture(), 27);
    expect(File(artifacts.backFull).existsSync(), false);
    expect(File(artifacts.backCrop).existsSync(), false);
    engine.quality = MessageResult.cardValid;
    expect(await capture(), MessageResult.cardValid);
    expect(engine.isFront, false);
    expect(await File(artifacts.backFull).readAsBytes(), full);
    expect(await File(artifacts.backCrop).readAsBytes(), crop);
    expect(artifacts.cropParamBack, '0.30,0.30');
  });

  test('empty scan component prevents any upload', () async {
    final directory = await Directory.systemTemp.createTemp();
    addTearDown(() => directory.delete(recursive: true));
    final files = await _artifacts(directory, scan: 'scan|');
    final server =
        _Server('{"message":"IDG-00000000","object":{"liveness":"success"}}');
    final core = _core(server);
    await core.configure(_config());
    final result = await core.runFullIdentityFromPaths(files.toPaths());
    expect(result.errorCode, 'SCAN3D');
    expect(server.calls, 0);
  });

  for (final (decision, expected) in [
    ('{"liveness":"success"}', true),
    ('{"liveness":false}', false),
    ('{"liveness":"success","fake_liveness":true}', false),
    ('{"liveness_msg":"response without a decision"}', false),
  ]) {
    test('HTTP success with $decision produces success=$expected', () async {
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      final files = await _artifacts(directory, scan: 'scan|capture');
      final server = _Server('{"message":"IDG-00000000","object":$decision}');
      final core = _core(server);
      await core.configure(_config());
      final result = await core.runFullIdentityFromPaths(files.toPaths());
      expect(server.calls, greaterThan(0));
      expect(result.success, expected);
      expect(result.errorCode, expected ? '' : 'LIVENESS');
      expect(vnptOcrAccepted(result.ocrJson), true);
    });
  }

  test('OCR envelope success without identity data is not accepted', () {
    expect(vnptOcrAccepted('{"message":"IDG-00000000","object":{"name":""}}'),
        false);
  });
}

Future<EkycSessionArtifacts> _artifacts(Directory folder,
    {required String scan}) async {
  final artifacts = EkycSessionArtifacts(folder);
  for (final path in [
    artifacts.frontFull,
    artifacts.backFull,
    artifacts.farPreview,
    artifacts.nearPreview
  ]) {
    await File(path).writeAsString('fixture');
  }
  await File(artifacts.scan3d).writeAsString(scan);
  return artifacts;
}
