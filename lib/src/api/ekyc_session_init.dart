import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

/// Thông tin thiết bị gửi lên backend khi tạo phiên eKYC (`sessions/init`).
///
/// Plugin không gọi `sessions/init`: backend của app tự gọi, body lấy từ [toJson].
class EkycSessionInitRequest {
  const EkycSessionInitRequest({
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.deviceType,
    required this.sdkVersion,
    required this.deviceId,
  });

  /// Dựng từ thông tin thiết bị native. `platform` viết hoa (`ANDROID`/`IOS`),
  /// `deviceType` là `Simulator` hoặc `Device`.
  factory EkycSessionInitRequest.fromDevice(
    NativeDeviceInfo device, {
    required String sdkVersion,
  }) =>
      EkycSessionInitRequest(
        platform: device.platform.toUpperCase(),
        deviceModel: device.model,
        osVersion: device.osVersion,
        deviceType: device.isSimulator ? 'Simulator' : 'Device',
        sdkVersion: sdkVersion,
        deviceId: device.deviceId,
      );

  final String platform;
  final String deviceModel;
  final String osVersion;
  final String deviceType;
  final String sdkVersion;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'deviceType': deviceType,
        'sdkVersion': sdkVersion,
        'deviceId': deviceId,
      };
}
