# Prompt: Gộp SDK eKYC 2.0 thành 1 Flutter plugin `vnpt_kyc_plugin`

> Dán toàn bộ nội dung dưới đây cho agent (Claude Code), chạy với working directory
> `/Users/juncook/Documents/Wikex/eKyc_vnpt/vnpt_v2`.

---

## Bối cảnh

Trong `vnpt_v2/` hiện có SDK eKYC 2.0 chia làm 3 package + 1 app demo:

| Nguồn | Vai trò | Ngôn ngữ |
|---|---|---|
| `packages/ekyc_platform` | Pigeon bridge + native gọi engine VNPT (`CardWrapper`, `Face3DWrapper`), crop ảnh oval, **và** HTTP gọi API VNPT | Dart (vỏ) + Kotlin + Swift |
| `packages/ekyc_sdk` | `EkycCore` điều phối session, artifacts, config | Dart |
| `packages/ekyc_ui` | `EkycCardScanner`, `EkycOvalScanner`, camera utils | Dart |
| `ekyc_sdk2_example` | App demo | Dart |

Mục tiêu: gộp tất cả thành **một Flutter plugin duy nhất** tại `vnpt_v2/vnpt_kyc_plugin/`
(package name `vnpt_kyc_plugin`), phân phối qua **git repo riêng** (không publish pub.dev vì kèm binary VNPT).

**Không được sửa/xoá gì trong `packages/` và `ekyc_sdk2_example/`** — đó là bản gốc để đối chiếu. Chỉ copy sang.

## Cấu trúc đích

```
vnpt_kyc_plugin/
├── pubspec.yaml                 # plugin: platforms android (package com.vnpt.vnpt_kyc_plugin) + ios
├── README.md  CHANGELOG.md  LICENSE  analysis_options.yaml  .gitignore
├── pigeon/native_ekyc_api.dart
├── lib/
│   ├── vnpt_kyc_plugin.dart     # export duy nhất, dùng `show` để giới hạn public API
│   └── src/
│       ├── core/      # từ ekyc_sdk (EkycCore, EkycConfig, SessionArtifacts, identity result)
│       ├── api/       # MỚI: VnptClient (Dart, package:http) + auth header
│       ├── ui/        # từ ekyc_ui (scanners) ; ui/camera/ cho stream/jpeg/boot utils
│       ├── platform/  # Pigeon generated + MessageResult + artifact constants
│       └── l10n/      # chuỗi tiếng Việt (hint, lỗi)
├── android/   # Kotlin: chỉ engine + xử lý ảnh + device info
├── ios/       # Swift:  chỉ engine + xử lý ảnh + device info
├── test/
└── example/   # từ ekyc_sdk2_example
```

## Thực hiện theo từng phase. Hết mỗi phase phải chạy được kiểm tra rồi mới sang phase sau.

### Phase 1 — Gộp nguyên trạng (KHÔNG đổi logic)
1. Tạo plugin skeleton (`flutter create --template=plugin --platforms=android,ios --org com.vnpt vnpt_kyc_plugin` rồi dọn file mẫu, hoặc tự viết).
2. Copy code Dart của 3 package vào `lib/src/{platform,core,ui}`; sửa toàn bộ import `package:ekyc_platform|ekyc_sdk|ekyc_ui/...` → relative import hoặc `package:vnpt_kyc_plugin/...`.
3. Gộp dependency vào `pubspec.yaml`: `camera`, `image`, `path_provider`, `path` (+ dev: `pigeon`, `flutter_test`, `flutter_lints`). Giữ `sdk: ^3.5.0`, `flutter: ">=3.22.0"`.
4. Copy test của `ekyc_sdk/test` và `ekyc_ui/test` vào `test/`.
5. Copy `ekyc_sdk2_example` → `example/`: bỏ `build/`, `.dart_tool/`, `.idea/`, `*.iml`, `.flutter-plugins-dependencies`, **và KHÔNG copy `env.local.json`** (chỉ copy `env.local.json.example`). Sửa pubspec example chỉ phụ thuộc `vnpt_kyc_plugin: { path: ../ }`, sửa import.
6. Kiểm tra: `flutter pub get` + `flutter analyze` sạch ở plugin và example.

### Phase 2 — Gộp native
1. **Android**: copy Kotlin sang package `com.vnpt.vnpt_kyc_plugin`, đổi `namespace`, plugin class trong pubspec. Copy `android/libs/ekyc_sdk-release-v3.7.4.aar` + `libs/README.md`; giữ cơ chế `flatDir` và `packaging.jniLibs.pickFirsts` như `packages/ekyc_platform/android/build.gradle`.
2. **iOS**: copy `Classes/*.swift`. `packages/ekyc_platform/ios/Frameworks/eKYCLib.xcframework` hiện là **symlink hỏng** (trỏ tới `/Users/mac/Downloads/...`). Thay bằng bản thật: copy thư mục (không symlink) từ `/Users/juncook/Documents/Wikex/eKyc_vnpt/SDK_ekyc_iOS_v3/eKYCLib.xcframework` (kiểm tra có model `.bic` trong framework). Chỉ thêm `ICSdkEKYC.xcframework` nếu code thực sự import.
3. Viết lại podspec `vnpt_kyc_plugin.podspec`: name/version/summary/homepage/author thật (để placeholder TODO rõ ràng nếu chưa biết), `vendored_frameworks`, `platform :ios`.
4. Chạy lại `dart run pigeon --input pigeon/native_ekyc_api.dart` với output path mới; đảm bảo file generated khớp.
5. Kiểm tra: `cd example && flutter build apk --debug` thành công; `flutter build ios --no-codesign --debug` thành công (nếu môi trường có Xcode). Báo rõ nếu bước nào không chạy được và vì sao.

### Phase 3 — Chuyển HTTP lên Dart
1. Viết `lib/src/api/vnpt_client.dart` (dùng `package:http`, inject `http.Client` để test) tái tạo **chính xác** hành vi hiện tại của `EkycVnptHttp.kt` / `EkycVnptHttp.swift` / `EkycPipelineBridge.*`:
   - `POST {base}/file-service/v1/addFile` multipart (`file`, `title`, `description`; mime `text/plain` cho file bắt đầu `3DFace_portrait`, còn lại `image/jpeg`), đọc `object.hash`.
   - `POST {base}/ai/v1/ocr/id?challenge_code=…` body: `type, img_front, img_back?, client_session, token, crop_param, flow/step_id` theo đúng điều kiện hiện có.
   - Liveness: `/ai/v1/face/liveness-3d` khi `checkLivenessFace == 1`, ngược lại `/ai/v1/standard/face/liveness-3d`; body `far_img, near_img, scan3d, client_session, flow | (token, step_id)`.
   - Headers: `Authorization` (logic chuẩn hoá Bearer như `EkycAuthHeader`), `token-id`, `token-key`, `Vnpt-Token`, `Content-Type`, `mac-address` (lấy từ config, default giữ `"TEST1"` để không đổi hành vi).
   - Logic chọn full vs crop (`pick`), `crop_param` fallback `"0.0,0.0"`, timeout 120s, message lỗi kèm tên bước (tiếng Việt) như hiện tại.
   - Log debug không bao giờ in credential (fingerprint như bản Swift).
2. `client_session`: so sánh `EkycClientSession.kt` và `.swift`; phần cần thông tin thiết bị thì thêm 1 HostApi nhỏ `deviceInfo()` trong Pigeon, phần còn lại build trong Dart.
3. `EkycCore.runFullIdentity*` gọi `VnptClient` thay cho `EkycNativePipeline`. Xoá `EkycNativePipeline` khỏi Pigeon, xoá các file HTTP/pipeline/auth native ở cả 2 nền tảng.
4. Unit test `test/vnpt_client_test.dart` với `MockClient`: kiểm tra URL, headers, body từng request, nhánh liveness iBeta/standard, nhánh flow/step_id, lỗi HTTP → `PipelineResult` lỗi đúng stage.

### Phase 4 — Sửa lỗi đã review
1. **Mã kết quả**: iOS đang trả `msg.rawValue` trực tiếp, Android map thủ công. Đọc header/swiftinterface của `eKYCLib.xcframework` để xác định enum iOS, rồi viết bảng map tường minh trên iOS sang `MessageResult` (0–10, 19, 20–30, -1) giống Android. Ghi chú nguồn đối chiếu trong code.
2. **Hint bắn 2 lần**: `validateCardFrame`/`processOvalFrame` tự `add` vào stream, đồng thời native gọi `EkycEngineEvents.onCardHint/onFaceHint` cũng `add`. Bỏ `EkycEngineEvents` (FlutterApi) hoàn toàn, chỉ dùng giá trị trả về.
3. Bỏ `static _eventsBound` trong `EkycCore`.
4. `processOvalFrame`: chỉ gọi `faceSetOvalPhase` / `faceSetPreviewSize` khi giá trị thay đổi (cache ở Dart).
5. `_appendFaceLog`: `phase <= 1 ? 20 : 15` luôn ra 20 — đối chiếu tài liệu VNPT (`/Users/juncook/Documents/Wikex/eKyc_vnpt/*.pdf`) để sửa đúng, nếu không xác định được thì giữ hành vi và thêm TODO.
6. Thay `existsSync/lengthSync` bằng bản async trong `runFullIdentityFromPaths`.
7. Sửa 6 cảnh báo `use_build_context_synchronously` trong example `test_hub.dart`.

### Phase 5 — Public API, tài liệu, đóng gói
1. `lib/vnpt_kyc_plugin.dart` chỉ export: `EkycCore`, `EkycConfig`, `EkycSessionArtifacts`, kết quả identity, `EkycCardScanner`, `EkycOvalScanner`, `MessageResult`, `PipelineResult`. Mọi thứ khác private.
2. Thêm API cấp cao `VnptEkyc.startFullFlow(BuildContext, EkycConfig) → Future<IdentityResult>` (trích logic từ `example/lib/guided_ekyc_flow.dart`), example dùng API này.
3. `README.md` (tiếng Việt): cài đặt qua git (`git: url, ref`), quyền camera (Android manifest, iOS `NSCameraUsageDescription`), yêu cầu model `.bic` + `noCompress` trên Android, minSdk 24 / iOS 12, cách chạy example với `--dart-define-from-file=env.local.json`, cảnh báo dart-define nhúng key vào binary.
4. `.gitignore` (gốc + example) phải có: `env.local.json`, `.env`, `build/`, `.dart_tool/`, `.idea/`, `*.iml`.
5. `CHANGELOG.md` mục `1.0.0`. `git init` trong `vnpt_kyc_plugin/` + commit đầu (kiểm tra `git status` không có `env.local.json` hay file secret). **Không push.**

## Kiểm tra cuối (bắt buộc báo kết quả thật, không đoán)
- `flutter analyze` — 0 issue ở plugin và example.
- `flutter test` — liệt kê pass/fail. Nếu lỗi thiếu `flutter_tester` (cache fvm 3.47.1 hỏng) thì chạy `flutter precache --force` rồi thử lại; vẫn lỗi thì báo.
- `flutter build apk --debug` trong example.
- `flutter build ios --no-codesign` nếu có thể.
- Bảng tóm tắt: file đã chuyển, file đã xoá, thay đổi hành vi (nếu có), TODO còn lại.

## Ràng buộc
- Không đổi hành vi nghiệp vụ ngoài các mục Phase 4; mọi khác biệt phải liệt kê.
- Không in/commit credential (ACCESS_TOKEN, TOKEN_ID, TOKEN_KEY).
- Không sửa thư mục gốc `packages/`, `ekyc_sdk2_example/`.
- Khi không chắc (enum iOS, face log status, license binary) → để TODO và hỏi, không bịa.
