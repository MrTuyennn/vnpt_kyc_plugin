# vnpt_kyc_plugin

Flutter plugin eKYC VNPT (SDK 2.0): quét CCCD hai mặt, xác thực khuôn mặt 3D (oval xa/gần),
upload + OCR + liveness qua API VNPT. Gồm engine native (Android AAR v3.7.4, iOS `eKYCLib.xcframework`),
UI quét bằng Flutter và client HTTP viết bằng Dart.

> Plugin kèm binary SDK của VNPT nên **không publish lên pub.dev**; phân phối qua git.

## Cài đặt

```yaml
dependencies:
  vnpt_kyc_plugin:
    git:
      url: https://example.com/your-org/vnpt_kyc_plugin.git  # TODO: URL repo thật
      ref: v1.0.0
```

Yêu cầu: Flutter ≥ 3.22, Dart ≥ 3.5, **Android minSdk 24**, **iOS 12+**.

## Cấu hình app host

### Android

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

Engine đọc các model `.bic` trong assets của AAR, nên **bắt buộc** không nén chúng
(`android/app/build.gradle.kts`):

```kotlin
android {
    androidResources {
        noCompress += "bic"
    }
}
```

Thiếu cấu hình này, `cardCreateInstance`/`faceCreateInstance` báo `MODEL_UNAVAILABLE`.

### iOS

`ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Cần dùng camera để chụp giấy tờ và xác thực khuôn mặt.</string>
```

Model `.bic` nằm trong `eKYCLib.xcframework` (đã kèm trong plugin). Lưu ý: slice simulator của
framework chỉ có `x86_64`; trên Mac Apple Silicon hãy chạy trên thiết bị thật hoặc simulator qua Rosetta.

## Sử dụng

```dart
import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

final config = EkycConfig(
  accessToken: '...',   // JWT, có hoặc không tiền tố "Bearer "
  tokenId: '...',
  tokenKey: '...',
);

final result = await VnptEkyc.startFullFlow(context, config);
if (result.success) {
  final card = vnptResponseObject(result.ocrJson); // thông tin CCCD
} else {
  debugPrint('${result.errorCode}: ${result.errorMessage}');
}
```

Muốn tự dựng màn hình: dùng `EkycCore` + `EkycCardScanner` / `EkycOvalScanner`
(xem `example/lib/test_hub.dart`).

## Chạy example

```bash
cd example
cp env.local.json.example env.local.json   # điền ACCESS_TOKEN, TOKEN_ID, TOKEN_KEY (file bị gitignore)
flutter pub get
flutter run --dart-define-from-file=env.local.json -d <device_id>
```

> **Cảnh báo bảo mật:** `--dart-define` nhúng giá trị vào binary; ai có APK/IPA đều trích được
> token. Chỉ dùng cho QA nội bộ. Production: cấp token từ backend của bạn lúc chạy, đừng nhúng khi build.

## Phát triển

```bash
flutter pub get
flutter analyze
flutter test
# Sau khi sửa pigeon/native_ekyc_api.dart:
flutter pub run pigeon --input pigeon/native_ekyc_api.dart
```

Cấu trúc: `lib/src/{core,api,ui,flow,platform,l10n}`; native chỉ chứa engine, xử lý ảnh và device info.
Binary Android: xem `android/libs/README.md` (SHA-256).
