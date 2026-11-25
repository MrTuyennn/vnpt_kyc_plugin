import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

void main() {
  test('delete() xoá thư mục của lần quét', () async {
    final dir = await Directory.systemTemp.createTemp('scan_result_');
    await File('${dir.path}/front.jpg').writeAsBytes([1]);
    final result = CardScanResult(
      side: VnptCardSide.front,
      fullImagePath: '${dir.path}/front.jpg',
      cropImagePath: '${dir.path}/front.jpg',
      cropParam: '0.1,0.1',
      sessionDir: dir.path,
    );
    await result.delete();
    expect(await dir.exists(), isFalse);
    await result.delete(); // gọi lại không lỗi
  });
}
