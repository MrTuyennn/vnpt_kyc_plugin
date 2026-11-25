# vnpt_kyc_plugin

Flutter plugin eKYC VNPT (SDK 2.0): quét **CCCD hai mặt**, **xác thực khuôn mặt 3D** (oval xa/gần),
rồi upload + **OCR** + **liveness 3D** qua API VNPT — chỉ với một lệnh gọi.

- Engine AI native của VNPT: Android AAR **v3.7.4**, iOS `eKYCLib.xcframework`.
- UI quét viết bằng Flutter (camera toàn màn hình, khung CCCD, khung oval có cung tiến độ, hướng dẫn tiếng Việt).
- Client HTTP viết bằng Dart — hành vi giống hệt nhau trên Android và iOS.

### Ba cách dùng

| Cách | Dùng khi | API chính |
|---|---|---|
| **Trọn gói** | Gọi thẳng API VNPT bằng token VNPT | `VnptEkyc.startFullFlow` |
| **Chỉ quét** | App tự upload / gọi API | `VnptEkyc.scanCard`, `VnptEkyc.scanFace` |
| **Qua proxy backend** | Backend cấp phiên eKYC (token theo phiên), như app Wikex | `EkycProxyClient`, `EkycIdentityVerifier` |

> ⚠️ Plugin kèm binary độc quyền của VNPT nên **không publish lên pub.dev**; phân phối qua git repo riêng.
> Chỉ dùng khi đơn vị của bạn có hợp đồng / giấy phép sử dụng SDK eKYC của VNPT.

---

## Mục lục

1. [Yêu cầu](#yêu-cầu)
2. [Cài đặt](#cài-đặt)
3. [Cấu hình app host](#cấu-hình-app-host)
4. [Bắt đầu nhanh (trọn gói)](#bắt-đầu-nhanh)
5. [Chỉ quét, app tự gọi API](#chỉ-quét-app-tự-gọi-api)
6. [Gọi API qua proxy backend](#gọi-api-qua-proxy-backend)
7. [Thông báo đa ngôn ngữ & giới hạn dung lượng](#thông-báo-đa-ngôn-ngữ--giới-hạn-dung-lượng)
8. [Cấu hình `EkycConfig`](#cấu-hình-ekycconfig)
9. [Kết quả & xử lý lỗi](#kết-quả--xử-lý-lỗi)
10. [Tự dựng luồng (API cấp thấp)](#tự-dựng-luồng-api-cấp-thấp)
11. [Kiến trúc](#kiến-trúc)
12. [Chạy example](#chạy-example)
13. [Bảo mật](#bảo-mật)
14. [Phát triển plugin](#phát-triển-plugin)
15. [Xử lý sự cố](#xử-lý-sự-cố)

---

## Yêu cầu

| | Tối thiểu |
|---|---|
| Flutter | 3.22 |
| Dart | 3.5 |
| Android | `minSdk 24` (Android 7.0) |
| iOS | 12.0, chạy trên **thiết bị thật** (xem [Xử lý sự cố](#xử-lý-sự-cố)) |
| Credential VNPT | `access token`, `token-id`, `token-key` (cấp từ cổng eKYC VNPT) |

## Cài đặt

`pubspec.yaml` của app:

```yaml
dependencies:
  vnpt_kyc_plugin:
    git:
      url: https://example.com/your-org/vnpt_kyc_plugin.git  # TODO: URL repo thật
      ref: v1.0.0
```

```bash
flutter pub get
```

> Repo nặng ~75 MB (AAR 34 MB + xcframework 90 MB trước nén) nên lần `pub get` đầu sẽ hơi lâu.

## Cấu hình app host

### Android

**1. Quyền camera** — `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**2. minSdk và không nén model `.bic`** — `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 24
    }
    androidResources {
        noCompress += "bic"   // BẮT BUỘC: engine mở model .bic trực tiếp từ assets
    }
}
```

<details>
<summary>Dùng Groovy (<code>build.gradle</code>)?</summary>

```groovy
android {
    defaultConfig { minSdkVersion 24 }
    aaptOptions { noCompress "bic" }
}
```
</details>

Thiếu `noCompress`, lúc mở camera sẽ báo lỗi `MODEL_UNAVAILABLE`.

### iOS

**1. Quyền camera** — `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Cần dùng camera để chụp giấy tờ và xác thực khuôn mặt.</string>
```

**2. Phiên bản iOS** — `ios/Podfile`:

```ruby
platform :ios, '12.0'
```

Model `.bic` nằm sẵn trong `eKYCLib.xcframework` (đã kèm plugin), không cần cấu hình thêm.

## Bắt đầu nhanh

```dart
import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

Future<void> verify(BuildContext context) async {
  final config = EkycConfig(
    accessToken: '<ACCESS_TOKEN>', // JWT, có hoặc không tiền tố "Bearer "
    tokenId: '<TOKEN_ID>',
    tokenKey: '<TOKEN_KEY>',
  );

  // Mở luồng: CCCD mặt trước → mặt sau → khuôn mặt → gửi VNPT.
  final result = await VnptEkyc.startFullFlow(context, config);

  if (result.success) {
    final card = vnptResponseObject(result.ocrJson);        // Map thông tin CCCD
    debugPrint('Số CCCD: ${card?['id']}, Họ tên: ${card?['name']}');
  } else if (result.errorCode == 'CANCELLED') {
    // người dùng đóng luồng
  } else {
    debugPrint('${result.errorCode}: ${result.errorMessage}');
  }
}
```

`startFullFlow` tự tạo `EkycCore`, gọi `configure` + `startSession`, đẩy màn hình luồng lên
`Navigator` và trả về `IdentityResult` khi xong. Truyền `core:` nếu muốn dùng lại một `EkycCore` có sẵn.

`result.success == true` nghĩa là **cả hai** điều kiện đều đạt:

- OCR: VNPT trả `message` thành công và có `object.id`, `object.name`;
- Liveness: `object.liveness` là `success`/`true`, đồng thời không có `fake_liveness` hay `face_swapping`.

## Chỉ quét, app tự gọi API

Plugin chỉ mở màn quét và trả về **file trên máy**, không gọi API nào. `null` nghĩa là
người dùng thoát giữa chừng (thư mục tạm đã được xoá).

```dart
final card = await VnptEkyc.scanCard(context, config, side: VnptCardSide.front);
// card.fullImagePath   ảnh đầy đủ
// card.cropImagePath   ảnh cắt theo khung quét
// card.cropParam       "top,bottom" ứng với ảnh đầy đủ (dùng cho crop_param của OCR)

final face = await VnptEkyc.scanFace(context, config);
// face.farImagePath, face.nearImagePath       khung hình đầy đủ
// face.farCropPath,  face.nearCropPath        bản cắt theo oval
// face.scan3dPath                              dữ liệu 3D (*.3dobj) cho API liveness
// face.faceLogPath                             null nếu enableFaceLog = false

await face?.delete(); // xoá file sau khi upload xong
```

- Mỗi lần gọi là **một phiên riêng** (thư mục `Documents/ekyc_session_<timestamp>`), nên mặt trước và mặt sau
  là hai thư mục khác nhau; `delete()` trên từng kết quả.
- `config` chỉ cần các tuỳ chọn quét (`modeFaceOval`, `stableFaceFrames`, `enableFaceLog`, …);
  token VNPT không dùng trong hai hàm này.

## Gọi API qua proxy backend

Dành cho app dùng **phiên eKYC của backend** (token theo phiên, không dùng token VNPT trực tiếp).
Port từ `EkycDatasource` của app Wikex.

### Tạo phiên (`sessions/init`) — do app/backend gọi

Plugin không gọi `sessions/init`. Lấy thông tin thiết bị để gửi lên:

```dart
final body = (await VnptEkyc.sessionInitRequest()).toJson();
// {platform, deviceModel, osVersion, deviceType, sdkVersion, deviceId}
```

Dùng cùng `deviceId` cho `EkycProxyClient(deviceId: …)`.

### `EkycProxyClient` — từng API

```dart
// response của POST sessions/init (app tự gọi); host là domain backend
final session = EkycProxySession.fromJson(initResponse, host: 'https://api.host');
final api = EkycProxyClient(session: session, deviceId: deviceId);
```

| Hàm | Gọi | Ghi chú |
|---|---|---|
| `addFile(path)` | `file-service/v1/addFile` | Trả `hash`; kiểm tra dung lượng trước khi gửi |
| `ocrCard(front:, hash:)` | `ai/v1/ocr/id/front` hoặc `/back` | Mặt trước gửi thêm `validate_postcode`; `type: -1` |
| `checkCardLiveness(hash)` | `ai/v1/card/liveness` | Ném `CARD_NOT_GENUINE` nếu `liveness != success` |
| `verifyIdCard(frontHash:, backHash:)` | `ai/v1/ocr/id` | Đối chiếu cặp hai mặt |
| `faceLiveness3d(far, near, scan3d)` | `ai/v1/face/liveness-3d` | iBeta; trả `isLive`, `faceSwapping`, `fakeLiveness` |
| `compareFace(frontHash:, faceHash:)` | `ai/v1/face/compare` | `isMatch` khi `msg == 'MATCH'` |
| `verifyCardSide(CardScanResult)` | addFile → ocr → (mặt trước) card/liveness | Upload ảnh crop |
| `verifyFace(FaceScanResult, {frontHash})` | addFile ×3 → liveness-3d → (có `frontHash`) compare | Ném `SPOOF_DETECTED` / `LIVENESS_FAILED` |

Header mọi request: `Authorization: Bearer <sessionToken>`, `X-Ekyc-Session-Token`, `Token-id`,
`Token-key`, `mac-address` (= `deviceId`); body có `challengeCode = sessionId`.
Thành công khi `wikex_ekyc.passed == true` và `errors` rỗng (không có `wikex_ekyc` thì dựa vào `message`).

> **Backend cần cung cấp** route `ai/v1/face/liveness-3d` (dưới `proxyBaseUrl`) nhận body `far_img`, `near_img`,
> `scan3d`, `client_session`, `token`, `challengeCode` và trả cùng định dạng `wikex_ekyc` / `object` như các route khác.
> Plugin chưa được thử với backend thật.

### `EkycIdentityVerifier` — điều phối cả luồng

`ChangeNotifier` chạy đúng luồng của Wikex:

1. Mặt trước: `addFile` → `ocr/id/front` → `card/liveness`. Mặt sau: `addFile` → `ocr/id/back`.
   Hai mặt chạy độc lập, lỗi hiện ở mặt đó.
2. Cả hai OCR thành công → `ocr/id` đối chiếu cặp (`pair`).
3. Khuôn mặt: liveness 3D (`face`).
4. Cặp đạt **và** có ảnh khuôn mặt → `face/compare` với ảnh mặt trước (`compare`).
5. `canContinue` chỉ `true` khi cặp đạt, `compare.isMatch` và đủ ba ảnh.

```dart
final verifier = EkycIdentityVerifier(api, locale: const Locale('vi'));
verifier.addListener(() { /* cập nhật UI */ });

await verifier.submitFront(frontScan);   // verifier.front.status / .error / .message
await verifier.submitBack(backScan);     // xong cả hai thì tự chạy verifier.pair
await verifier.submitFace(faceScan);     // có cặp đạt thì tự chạy verifier.compare
if (verifier.canContinue) { /* bật nút Tiếp tục */ }

if (verifier.sessionExpired) {           // SESSION_NOT_ACTIVE: đã xoá hết kết quả
  verifier.replaceClient(newApi);        // phiên mới, rồi cho người dùng làm lại từ đầu
}
```

- Chụp lại mặt trước/sau → cặp và so khớp chạy lại; chụp lại khuôn mặt → chỉ so khớp chạy lại.
- Kết quả của lần gọi cũ bị bỏ qua (counter theo từng bước).
- Liveness lỗi khi làm lại → bỏ kết quả khuôn mặt và so khớp cũ.
- Bước nào cũng là `IdentityStep` (`status`: `idle | running | success | failure`, `value`, `error`, `message`).

### Mã lỗi `EkycProxyException.code`

| Code | Nghĩa |
|---|---|
| `IDG-…` | Mã lỗi VNPT (xem bảng map trong `EkycMessages.forError`) |
| `RECAPTURED_DOCUMENT` | Ảnh giấy tờ chụp lại từ màn hình / bản in |
| `SESSION_NOT_ACTIVE` | Phiên đã hoàn tất hoặc hết hạn → tạo phiên mới |
| `CARD_NOT_GENUINE` | `card/liveness` từ chối giấy tờ |
| `SPOOF_DETECTED` | `face_swapping` hoặc `fake_liveness` |
| `LIVENESS_FAILED` | Liveness 3D không đạt |
| `FILE_TOO_LARGE` | File vượt giới hạn dung lượng |
| `NETWORK` | Mất kết nối, timeout (60 giây) hoặc server trả 5xx |

4xx vẫn được đọc body (`errors`); chỉ 5xx là lỗi hạ tầng.

## Thông báo đa ngôn ngữ & giới hạn dung lượng

**Ngôn ngữ:** truyền `locale` — dựng sẵn `vi` và `en`, ngôn ngữ khác dùng `vi`.

```dart
final verifier = EkycIdentityVerifier(api, locale: const Locale('en'));
verifier.setLocale(const Locale('vi'));                         // đổi sau
verifier.setMessages(EkycMessages.en.copyWith(faceMismatch: '…')); // hoặc chuỗi riêng

final text = EkycMessages.of(const Locale('en')).forError(exception); // dùng không qua verifier
```

- Mỗi bước lỗi có `step.message` đã dịch; `compare` không khớp cũng có `message` (`faceMismatch`).
- Mã lỗi chưa có bản dịch → `message` là nội dung gốc của server.
- `IDG-00010003` dùng chung cho hai lỗi nên được phân biệt bằng nội dung (`khong cung loai` → hai mặt khác loại).

### Ngôn ngữ giao diện quét (`EkycStrings`)

Màn luồng, màn quét CCCD và màn quét khuôn mặt đọc chuỗi từ `EkycConfig`:

```dart
final config = EkycConfig(
  locale: const Locale('en'),                     // dựng sẵn: vi (mặc định), en
  // strings: EkycStrings.en.copyWith(next: 'Go'), // hoặc chuỗi riêng, ghi đè locale
);
await VnptEkyc.scanCard(context, config, side: VnptCardSide.front); // UI tiếng Anh
```

- Gồm tiêu đề, gợi ý camera, nút chụp, nhắc vị trí thẻ/khuôn mặt, thông báo lỗi khi quét.
- Lỗi mở camera luôn dùng chuỗi `cameraUnavailable` đã dịch (chi tiết kỹ thuật chỉ ghi log).
- `EkycStrings` (giao diện) và `EkycMessages` (kết quả gọi API) là hai bộ riêng.

**Dung lượng:** mỗi file upload tối đa **5 MB** (`ekycMaxImageBytes`). `EkycProxyClient.addFile` tự kiểm tra
trước khi gửi và ném `FILE_TOO_LARGE` (không gọi mạng). Đổi bằng `maxFileBytes:` (`null` để tắt);
`isEkycFileTooLarge(path)` dùng riêng được.


## Cấu hình `EkycConfig`

| Thuộc tính | Mặc định | Ý nghĩa |
|---|---|---|
| `accessToken` | `''` | JWT của VNPT. Tự thêm `Bearer ` nếu thiếu, không bị nhân đôi. **Bắt buộc** |
| `tokenId` | `''` | Header `token-id`. **Bắt buộc** |
| `tokenKey` | `''` | Header `token-key`. **Bắt buộc** |
| `baseUrl` | `https://api.idg.vnpt.vn` | Gốc API VNPT |
| `challengeCode` | `'11111'` | Query `challenge_code` |
| `documentType` | `-1` | Trường `type` gửi OCR (`-1` = VNPT tự nhận diện) |
| `modeFaceOval` | `0` | `0` xa + gần, `1` chỉ xa, `2` chỉ gần |
| `checkLivenessFace` | `2` | `1` = iBeta (`/ai/v1/face/liveness-3d`), `2` = standard (`/ai/v1/standard/face/liveness-3d`) |
| `stableFaceFrames` | `2` | Số frame liên tiếp "khớp khung" trước khi chụp khuôn mặt |
| `faceFlowTimeoutSec` | `120` | Thời gian tối đa cho bước khuôn mặt (giây; Android ép tối thiểu 10) |
| `jpegQuality` | `80` | Chất lượng JPEG lưu/upload |
| `previewHeight` | `180` | Chiều cao ảnh đưa vào engine |
| `ocrToken` | token không watermark | Header `Vnpt-Token` và trường `token` |
| `isAutoCropParam` | `false` | `true` → luôn gửi `crop_param = "0.0,0.0"` |
| `clientSession` | `''` | Rỗng → tự sinh từ thông tin thiết bị |
| `flowEkyc` / `stepId` | `''` / `0` | Gửi `flow` / `step_id` nếu tích hợp theo flow VNPT |
| `enableFaceLog` | `true` | Ghi log từng frame khuôn mặt (đưa vào chữ ký capture) |
| `macAddress` | `'TEST1'` | Header `mac-address` |
| `locale` | `vi` | Ngôn ngữ giao diện quét/luồng (`vi`, `en`) |
| `strings` | `null` | `EkycStrings` riêng, ghi đè `locale` |
| `sdkVersionLabel` | `'3.7.4'` | Nhãn phiên bản trong `client_session` |

`config.isValidForApi` trả `true` khi đã có đủ `accessToken`, `tokenId`, `tokenKey`, `baseUrl`.

## Kết quả & xử lý lỗi

`IdentityResult` (alias của `PipelineResult`):

| Trường | Kiểu | Nội dung |
|---|---|---|
| `success` | `bool` | Xác thực thành công |
| `ocrJson` | `String` | JSON thô từ `/ai/v1/ocr/id` (có thể có cả khi lỗi ở bước liveness) |
| `liveness3dJson` | `String` | JSON thô từ API liveness 3D |
| `errorCode` | `String` | Mã lỗi (bảng dưới) |
| `errorMessage` | `String` | Thông báo tiếng Việt, có thể hiển thị cho người dùng |

Helper: `vnptResponseObject(json)` lấy `object`, `vnptOcrAccepted(json)`, `vnptLivenessAccepted(json)`.

| `errorCode` | Khi nào | Gợi ý xử lý |
|---|---|---|
| `CANCELLED` | Người dùng thoát trước khi gửi | Không cần báo lỗi |
| `CONFIG` | Thiếu credential / `baseUrl`, hoặc chưa `configure()` | Kiểm tra `EkycConfig` |
| `CARD_IMAGES` | Thiếu ảnh mặt trước hoặc mặt sau | Chụp lại CCCD |
| `OVAL_FILES` | Thiếu ảnh khuôn mặt hoặc dữ liệu 3D | Làm lại bước khuôn mặt |
| `SCAN3D` | Dữ liệu 3D rỗng / sai định dạng | Làm lại bước khuôn mặt |
| `ARTIFACTS` | Không đọc được file trong thư mục phiên | Kiểm tra bộ nhớ, tạo phiên mới |
| `UPLOAD` | Upload `/file-service/v1/addFile` lỗi hoặc không có hash | Kiểm tra mạng, token |
| `API` | OCR / liveness trả HTTP lỗi (401, 403, 5xx…) | Xem `errorMessage` (có HTTP code và body) |
| `PIPELINE` | Timeout (120s), lỗi mạng, lỗi không xác định | Thử lại |
| `OCR` | HTTP thành công nhưng VNPT không trả đủ thông tin CCCD | Chụp lại CCCD rõ hơn |
| `LIVENESS` | VNPT không xác nhận khuôn mặt thật | Làm lại bước khuôn mặt |

Ngoài bảng trên, `MODEL_UNAVAILABLE` là `PlatformException` do engine Android ném ra khi mở scanner
(không nằm trong `IdentityResult`): scanner hiện thông báo lỗi camera. Nguyên nhân là thiếu `noCompress += "bic"`.

Bảng trên áp dụng cho `startFullFlow` / `VnptClient`. Lỗi của `EkycProxyClient` là `EkycProxyException`
(xem [mã lỗi proxy](#mã-lỗi-ekycproxyexceptioncode)).

Với `UPLOAD`/`API`/`PIPELINE`, `errorMessage` có dạng `Bước: <tên bước>\nLỗi: <chi tiết>` để biết lỗi ở đâu.

## Tự dựng luồng (API cấp thấp)

Khi cần UI / thứ tự bước riêng, dùng trực tiếp `EkycCore` và hai widget scanner:

```dart
final core = EkycCore();
await core.configure(config);
await core.startSession(); // tạo thư mục phiên trong Documents

// 1. CCCD — mỗi widget tự mở camera, kiểm tra frame, chụp và lưu ảnh; pop(true) khi xong.
final front = await Navigator.push<bool>(context,
    MaterialPageRoute(builder: (_) => EkycCardScanner(core: core, isFront: true)));
final back = await Navigator.push<bool>(context,
    MaterialPageRoute(builder: (_) => EkycCardScanner(core: core, isFront: false)));

// 2. Khuôn mặt (oval xa → gần), lưu ảnh + dữ liệu 3D.
final face = await Navigator.push<bool>(context,
    MaterialPageRoute(builder: (_) => EkycOvalScanner(
          core: core,
          modeFaceOval: config.modeFaceOval,
          stableFrames: config.stableFaceFrames,
        )));

// 3. Gửi VNPT.
if (front == true && back == true && face == true) {
  final result = await core.runFullIdentity();
}
```

Những thứ khác hữu ích trên `EkycCore`:

| API | Dùng để |
|---|---|
| `cardHints`, `faceHints` | `Stream<int>` mã gợi ý theo từng frame (so với `MessageResult`, đổi sang chữ bằng `messageResultLabel`) |
| `artifacts` | `EkycSessionArtifacts`: đường dẫn ảnh/3D của phiên hiện tại |
| `resumeSession(dir)` | Mở lại một phiên đã lưu (ví dụ gửi lại khi mất mạng) |
| `runFullIdentityFromPaths(paths)` | Gửi VNPT từ bộ file tuỳ ý (`FullIdentityArtifactPaths`) |

Các hằng `MessageResult` thường gặp: `fit` (1), `noFace` (0), `tooFar` (2), `tooNear` (3),
`timeExceed` (4), `manyFaces` (19), `cardValid` (20), `noCard` (21), `invalid` (-1).

## Kiến trúc

```
App host
   │  VnptEkyc.startFullFlow / scanCard / scanFace  ·  EkycProxyClient / EkycIdentityVerifier
   │  hoặc EkycCore + EkycCardScanner / EkycOvalScanner
   ▼
lib/src/
├── flow/       VnptEkyc (startFullFlow, scanCard, scanFace), màn hình luồng, CardScanResult/FaceScanResult
├── ui/         scanner, camera stream, khung oval, chuyển frame → JPEG
├── core/       EkycCore: phiên, artifacts, config, kiểm tra kết quả VNPT
├── api/        VnptClient (gọi VNPT trực tiếp) · EkycProxyClient + EkycIdentityVerifier (qua proxy backend)
│               · ekyc_file_limits (giới hạn 5 MB) · ekyc_session_init
├── platform/   Pigeon bridge, MessageResult
└── l10n/       EkycStrings (giao diện quét/luồng, vi/en) · EkycMessages (thông báo lỗi API, vi/en)
   │  Pigeon (chỉ engine + ảnh + device info, không có credential)
   ▼
android/ (Kotlin)  ·  ios/ (Swift)
   │  CardWrapper / Face3DWrapper, crop/scale ảnh, map mã kết quả
   ▼
VNPT eKYC SDK: ekyc_sdk-release-v3.7.4.aar  ·  eKYCLib.xcframework
```

Luồng gọi API trực tiếp VNPT (Dart, `VnptClient`; dùng bởi `startFullFlow`):

1. `POST /file-service/v1/addFile` × 5 — ảnh CCCD trước, sau, khuôn mặt xa, gần, file `3DFace_portrait.3dobj` → lấy `hash`.
2. `POST /ai/v1/ocr/id` — `img_front`, `img_back`, `crop_param`, `client_session`, `token`.
3. `POST /ai/v1/standard/face/liveness-3d` (hoặc `/ai/v1/face/liveness-3d` nếu iBeta) — `far_img`, `near_img`, `scan3d`.

Credential chỉ nằm ở Dart; native không nhận và không gửi request mạng. Luồng proxy dùng token của phiên (`EkycProxySession`), không dùng token VNPT.

## Chạy example

```bash
cd example
cp env.local.json.example env.local.json   # điền ACCESS_TOKEN, TOKEN_ID, TOKEN_KEY
flutter pub get
flutter run --dart-define-from-file=env.local.json -d <device_id>
```

Example chỉ có một màn: mở app là vào thẳng luồng `VnptEkyc.startFullFlow` (màn các bước CCCD mặt trước,
mặt sau, khuôn mặt). Thoát luồng thì hiện nút "Bắt đầu xác thực" để mở lại; xong thì hiện kết quả OCR hoặc lỗi
dạng chữ. Credential chỉ nhận từ `--dart-define-from-file` (không có màn Cài đặt). Test thủ công: `example/TESTING.md`.

## Bảo mật

- `env.local.json` và `.env` đã nằm trong `.gitignore` — **không commit** file chứa token.
- `--dart-define` **nhúng giá trị vào binary**: ai có APK/IPA đều trích được token. Chỉ dùng cho QA nội bộ.
- Production: lấy `accessToken` (ngắn hạn) từ backend của bạn lúc chạy rồi truyền vào `EkycConfig`.
- Log debug của plugin không in credential (chỉ in fingerprint SHA-256 rút gọn).
- Ảnh CCCD và khuôn mặt được lưu trong thư mục `Documents/ekyc_session_<timestamp>` của app;
  xoá thư mục `core.artifacts` sau khi dùng xong nếu không cần giữ lại. Với `scanCard` / `scanFace`, gọi `result.delete()`.
- Ảnh và file 3D là dữ liệu nhạy cảm: chỉ upload qua kênh HTTPS của bạn và xoá file sau khi gửi.

## Phát triển plugin

```bash
flutter pub get
flutter analyze
flutter test                       # unit test core, VnptClient / EkycProxyClient (mock HTTP), verifier, messages, xử lý ảnh
cd example && flutter build apk --debug
```

Sau khi sửa `pigeon/native_ekyc_api.dart`:

```bash
flutter pub run pigeon --input pigeon/native_ekyc_api.dart
```

Nâng cấp binary VNPT:

- **Android**: thay file trong `android/libs/`, sửa tên trong `android/build.gradle` và SHA-256 trong `android/libs/README.md`.
- **iOS**: thay `ios/Frameworks/eKYCLib.xcframework` (thư mục thật, không dùng symlink), kiểm tra lại bảng map enum trong `ios/Classes/EkycEngineBridge.swift`.

Phát hành: cập nhật `version` trong `pubspec.yaml` + `ios/vnpt_kyc_plugin.podspec`, ghi `CHANGELOG.md`, rồi tạo tag `vX.Y.Z`.

## Xử lý sự cố

| Triệu chứng | Nguyên nhân / cách sửa |
|---|---|
| `MODEL_UNAVAILABLE` trên Android | Thiếu `noCompress += "bic"` trong app host |
| Lỗi build `minSdkVersion 21 cannot be smaller than 24` | Đặt `minSdk = 24` trong app host |
| iOS simulator trên Mac Apple Silicon không build/link được | Slice simulator của `eKYCLib.xcframework` chỉ có `x86_64` → chạy trên iPhone thật |
| Màn hình camera báo "Không mở được camera" | Chưa cấp quyền camera, hoặc thiếu `NSCameraUsageDescription` |
| `API` với `HTTP 401/403` | Token hết hạn hoặc sai `token-id` / `token-key` |
| `OCR` dù ảnh đã chụp | Ảnh mờ/loá; chụp lại nơi đủ sáng, thẻ nằm trọn trong khung |
| `LIVENESS` | Đeo kính râm/khẩu trang, ánh sáng ngược, hoặc dùng ảnh/màn hình thay mặt thật |
| Bước khuôn mặt báo hết thời gian | Tăng `faceFlowTimeoutSec` |
| `FILE_TOO_LARGE` | Ảnh quá 5 MB: giảm `jpegQuality` hoặc tăng `maxFileBytes` |
| `SESSION_NOT_ACTIVE` | Phiên proxy đã hoàn tất/hết hạn: lấy phiên mới, `verifier.replaceClient(...)` |
| `compare.isMatch == false` | Khuôn mặt không khớp ảnh mặt trước; cho quét lại khuôn mặt (không phải lỗi mạng) |
| Liveness proxy trả 404 | Backend chưa có route `ai/v1/face/liveness-3d` (xem ghi chú ở mục proxy) |

---

Giấy phép: xem `LICENSE`. Binary SDK thuộc bản quyền VNPT. Lịch sử thay đổi: `CHANGELOG.md`.
