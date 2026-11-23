import 'dart:io';

import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session metadata restores both crop parameters', () async {
    final dir = await Directory.systemTemp.createTemp('ekyc_session_test_');
    addTearDown(() => dir.delete(recursive: true));
    final original = EkycSessionArtifacts(dir)
      ..cropParamFront = '0.1,0.2'
      ..cropParamBack = '0.3,0.4';
    await original.saveMetadata();
    final restored = EkycSessionArtifacts(dir);
    await restored.loadMetadata();
    expect(restored.cropParamFront, '0.1,0.2');
    expect(restored.cropParamBack, '0.3,0.4');
  });
}
