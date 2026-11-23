import Flutter
import UIKit

public class VnptKycPlugin: NSObject, FlutterPlugin {
  private var engineBridge: EkycEngineBridge?
  private var deviceBridge: DeviceInfoBridge?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let defaultCfg = NativeEngineConfig(
      jpegQuality: 80,
      previewHeight: 180,
      ocrToken: "8928skjhfa89298jahga1771vbvb",
      isAutoCropParam: false
    )
    let engine = EkycEngineBridge(config: defaultCfg)
    let device = DeviceInfoBridge()
    let instance = VnptKycPlugin()
    instance.engineBridge = engine
    instance.deviceBridge = device
    EkycNativeEngineSetup.setUp(binaryMessenger: messenger, api: engine)
    EkycDeviceApiSetup.setUp(binaryMessenger: messenger, api: device)
  }
}

/// Thông tin thiết bị để Dart dựng `client_session` (xem `buildClientSession`).
final class DeviceInfoBridge: EkycDeviceApi {
  func deviceInfo() throws -> NativeDeviceInfo {
    let device = UIDevice.current
    #if targetEnvironment(simulator)
    let simulator = true
    #else
    let simulator = false
    #endif
    return NativeDeviceInfo(
      platform: "IOS",
      model: device.model,
      osVersion: device.systemVersion,
      isSimulator: simulator,
      deviceId: device.identifierForVendor?.uuidString ?? "",
      appId: Bundle.main.bundleIdentifier ?? ""
    )
  }
}
