package com.vnpt.vnpt_kyc_plugin

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin

class VnptKycPlugin : FlutterPlugin {
  private var engineBridge: EkycEngineBridge? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val messenger = binding.binaryMessenger
    val context = binding.applicationContext
    engineBridge = EkycEngineBridge(context)
    EkycNativeEngine.setUp(messenger, engineBridge)
    EkycDeviceApi.setUp(messenger, DeviceInfoBridge(context))
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    engineBridge?.cardDeleteInstance()
    engineBridge?.faceDeleteInstance()
    EkycNativeEngine.setUp(binding.binaryMessenger, null)
    EkycDeviceApi.setUp(binding.binaryMessenger, null)
    engineBridge = null
  }
}

/** Thông tin thiết bị để Dart dựng `client_session` (xem `buildClientSession`). */
private class DeviceInfoBridge(private val context: android.content.Context) : EkycDeviceApi {
  override fun deviceInfo(): NativeDeviceInfo {
    val androidId =
      Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
    return NativeDeviceInfo(
      platform = "ANDROID",
      model = Build.MODEL ?: "Unknown",
      osVersion = Build.VERSION.SDK_INT.toString(),
      isSimulator = Build.FINGERPRINT.contains("generic"),
      deviceId = androidId,
      appId = context.packageName,
    )
  }
}
