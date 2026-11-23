import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

class _Engine extends EkycNativeEngine {
  int phaseCalls = 0;
  int sizeCalls = 0;
  bool? lastPhase;
  int code = MessageResult.fit;

  @override
  Future<void> configure(NativeEngineConfig config) async {}
  @override
  Future<void> faceCreateInstance(int timeLimitSec) async {}
  @override
  Future<void> faceSetOvalPhase(bool isFar) async {
    phaseCalls++;
    lastPhase = isFar;
  }

  @override
  Future<void> faceSetPreviewSize(int width, int height) async => sizeCalls++;
  @override
  Future<int> faceProcessFrame(Uint8List jpeg) async => code;
  @override
  Future<int> cardValidateV2(Uint8List jpeg, bool isFront) async => 27;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('processOvalFrame chỉ gọi native khi phase/preview đổi', () async {
    final engine = _Engine();
    final core = EkycCore(engine: engine);
    final frame = Uint8List(1);
    Future<int> run(int phase, int w, int h) => core.processOvalFrame(frame,
        phase: phase, frameWidth: w, frameHeight: h);
    for (var i = 0; i < 5; i++) {
      await run(0, 480, 640);
    }
    expect(engine.phaseCalls, 1);
    expect(engine.sizeCalls, 1);
    await run(1, 480, 640);
    expect(engine.phaseCalls, 2);
    expect(engine.lastPhase, false);
    expect(engine.sizeCalls, 1);
    await run(1, 720, 960);
    expect(engine.phaseCalls, 2);
    expect(engine.sizeCalls, 2);
  });

  test('mỗi frame chỉ phát đúng một hint (không bắn đôi)', () async {
    final core = EkycCore(engine: _Engine());
    final face = <int>[];
    final card = <int>[];
    core.faceHints.listen(face.add);
    core.cardHints.listen(card.add);
    await core.processOvalFrame(Uint8List(1),
        phase: 0, frameWidth: 1, frameHeight: 1);
    await core.validateCardFrame(Uint8List(1), isFront: true);
    await Future<void>.delayed(Duration.zero);
    expect(face, [MessageResult.fit]);
    expect(card, [27]);
  });
}
