import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

void main() {
  test('EkycSessionInitRequest.fromDevice dựng body sessions/init', () {
    final json = const EkycSessionInitRequest(
      platform: 'IOS',
      deviceModel: 'iPhone',
      osVersion: '18',
      deviceType: 'Device',
      sdkVersion: '3.7.4',
      deviceId: 'id',
    ).toJson();
    expect(json.keys, [
      'platform',
      'deviceModel',
      'osVersion',
      'deviceType',
      'sdkVersion',
      'deviceId',
    ]);
  });

  test('EkycStrings.of chọn theo locale, mặc định vi', () {
    expect(EkycStrings.of(const Locale('en')), same(EkycStrings.en));
    expect(EkycStrings.of(const Locale('vi')), same(EkycStrings.vi));
    expect(EkycStrings.of(const Locale('ja')), same(EkycStrings.vi));
  });

  test('EkycConfig.locale / strings quyết định chuỗi của core', () {
    final core = EkycCore();
    expect(core.strings, same(EkycStrings.vi)); // chưa configure
    final config = EkycConfig(locale: const Locale('en'));
    expect(config.resolvedStrings, same(EkycStrings.en));
    final custom = EkycStrings.en.copyWith(next: 'Go');
    config.strings = custom;
    expect(config.resolvedStrings.next, 'Go');
    expect(config.resolvedStrings.back, EkycStrings.en.back);
  });

  test('captureLabel theo mặt', () {
    expect(EkycStrings.en.captureLabel(true), 'Capture front');
    expect(EkycStrings.vi.captureLabel(false), 'Chụp mặt sau');
  });
}
