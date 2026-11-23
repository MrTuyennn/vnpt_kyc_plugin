import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

/// Dựng `client_session` giống `EkycClientSession.kt` / `.swift`.
///
/// - Android: `ANDROID_{model}_{sdkInt}_{kind}_{label}_{androidId}_{ts}_{package}`
/// - iOS: `IOS_{model}_ios{systemVersion}_{kind}_{label}_{idfv}_{ts}_{bundleId}`
String buildClientSession({
  required NativeDeviceInfo device,
  required String sdkVersionLabel,
  required String override,
  required int timestampMs,
}) {
  if (override.isNotEmpty) return override;
  final kind = device.isSimulator ? 'Simulator' : 'Device';
  final isIos = device.platform.toUpperCase() == 'IOS';
  final prefix = isIos ? 'IOS' : 'ANDROID';
  final os = isIos ? 'ios${device.osVersion}' : device.osVersion;
  return '${prefix}_${device.model}_${os}_${kind}_${sdkVersionLabel}_'
      '${device.deviceId}_${timestampMs}_${device.appId}';
}
