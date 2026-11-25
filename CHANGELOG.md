# Changelog

## 1.0.0 — 2026-11-24

Bản đầu tiên. Gộp SDK eKYC 2.0 (`ekyc_platform` + `ekyc_sdk` + `ekyc_ui`) thành một Flutter plugin duy nhất
(Android AAR v3.7.4, iOS `eKYCLib.xcframework`), chuyển toàn bộ HTTP sang Dart và bổ sung ba cách dùng.

### Thêm

**Ba cách dùng**
- **Trọn gói:** `VnptEkyc.startFullFlow(context, config)` chạy CCCD mặt trước → mặt sau → khuôn mặt → gửi VNPT (upload, OCR, liveness 3D).
- **Chỉ quét:** `VnptEkyc.scanCard(context, config, side:)` và `VnptEkyc.scanFace(context, config)` chỉ mở màn quét và trả file
  (`CardScanResult`, `FaceScanResult`, có `delete()`), không gọi API; app tự `addFile`, OCR, liveness.
- **Qua proxy backend:** `EkycProxyClient` và `EkycIdentityVerifier`, xem bên dưới.

**Client HTTP bằng Dart**
- `VnptClient` (`package:http`): upload `addFile`, OCR `/ai/v1/ocr/id`, liveness 3D (iBeta hoặc standard). Thay toàn bộ HTTP native.
- `EkycProxyClient`: gọi proxy VNPT của backend bằng token phiên eKYC (`EkycProxySession`): `addFile`, `ocr/id/front|back`,
  `card/liveness`, `ocr/id`, `face/compare`, `face/liveness-3d`, cùng `verifyCardSide` và `verifyFace`. Lỗi ném `EkycProxyException`
  (`IDG-…`, `SESSION_NOT_ACTIVE`, `CARD_NOT_GENUINE`, `SPOOF_DETECTED`, `LIVENESS_FAILED`, `FILE_TOO_LARGE`, `NETWORK`).
- `EkycIdentityVerifier` (`ChangeNotifier`): điều phối mặt trước/sau độc lập → đối chiếu cặp → liveness khuôn mặt → so khớp với ảnh mặt trước;
  `canContinue`, chụp lại chỉ chạy lại các bước phụ thuộc, bỏ kết quả của lần gọi cũ, xử lý `SESSION_NOT_ACTIVE` (`replaceClient`).
- `VnptEkyc.sessionInitRequest()` dựng body `sessions/init` (thông tin thiết bị) cho backend.
- Giới hạn 5 MB mỗi file upload: `ekycMaxImageBytes`, `isEkycFileTooLarge`, `EkycProxyClient.maxFileBytes`.

**Đa ngôn ngữ (`vi`, `en`)**
- `EkycStrings` + `EkycConfig.locale` / `strings`: giao diện màn luồng, quét CCCD, quét khuôn mặt.
- `EkycMessages` + `EkycIdentityVerifier(locale:)`: thông báo lỗi API đã dịch (`IdentityStep.message`, `forError`), có `copyWith`.

**Giao diện**
- Màn quét CCCD: camera toàn màn hình, khung thẻ rộng 86% chiều ngang, nút quay lại tròn, tiêu đề và gợi ý; ảnh cắt khớp đúng khung trên màn hình.
- Màn quét khuôn mặt: camera phủ kín, vòng oval giữ nguyên tỉ lệ với vùng engine cắt, cung tiến độ xanh (pha xa nửa vòng đầu, pha gần nửa vòng sau),
  thông báo trạng thái dạng pill dưới oval.
- Màn luồng (`EkycFlowScreen`): hiển thị ảnh đầy đủ mặt trước và mặt sau theo cột, chạm để xem toàn màn hình (zoom được).

**Khác**
- Pigeon `EkycDeviceApi.deviceInfo()` để Dart dựng `client_session`.
- `EkycConfig.macAddress` (mặc định `TEST1`, như trước), `EkycConfig.locale`, `EkycConfig.strings`.
- Public API giới hạn bằng `export … show`; mọi thứ khác nằm trong `lib/src/`.
- README tiếng Việt đầy đủ (cài đặt, cấu hình app host, ba cách dùng, mã lỗi, kiến trúc, bảo mật, xử lý sự cố).

### Thay đổi
- `EkycConfigStore` → `EkycConfig`.
- Credential VNPT không còn gửi xuống native; native chỉ nhận `NativeEngineConfig`
  (`jpegQuality`, `previewHeight`, `ocrToken`, `isAutoCropParam`).
- `EkycNativePipeline` bị xoá; `EkycCore.runFullIdentity*` gọi `VnptClient`.
- iOS: mã lỗi pipeline theo Android (`UPLOAD` / `API` / `PIPELINE`, message "Bước: …\nLỗi: …") thay cho `UPLOAD_HTTP_<n>`.
- Android: bỏ phụ thuộc `okhttp`, `gson` (không còn dùng).
- Mã kết quả iOS map tường minh sang `MessageResult` (giống Android); giá trị enum iOS không có tương ứng (11–18, 31–35) trả `-1` thay vì raw value.
- Example rút gọn còn một màn: mở app là vào thẳng luồng `startFullFlow`; credential chỉ nhận qua `--dart-define-from-file`
  (bỏ màn Cài đặt, Test hub, màn kết quả cũ).

### Sửa lỗi
- Hint bắn 2 lần mỗi frame (stream + `EkycEngineEvents`): bỏ `EkycEngineEvents`, chỉ dùng giá trị trả về; bỏ `static _eventsBound`.
- `processOvalFrame` chỉ gọi `faceSetOvalPhase` / `faceSetPreviewSize` khi giá trị đổi.
- `runFullIdentityFromPaths` kiểm tra file bất đồng bộ.
- Sửa `use_build_context_synchronously` trong example.
- iOS: thay symlink hỏng của `eKYCLib.xcframework` bằng bản thật.

### Xoá
- Kênh debug `vnpt_ekyc/diagnostics` (chỉ phục vụ log HTTP native, giờ log ở Dart).

### Lưu ý và việc còn lại
- **Chưa thử với backend thật:** `EkycProxyClient` được viết theo cách app Wikex xử lý proxy và kiểm bằng `MockClient`. Backend cần có route
  `ai/v1/face/liveness-3d` dưới `proxyBaseUrl` (body `far_img`, `near_img`, `scan3d`, `client_session`, `token`, `challengeCode`) và trả
  định dạng `wikex_ekyc` / `object` như các route khác.
- **iOS simulator:** slice simulator của `eKYCLib.xcframework` chỉ có `x86_64`; chạy trên iPhone thật hoặc Rosetta.
- **Giấy phép:** plugin kèm binary SDK của VNPT, không publish lên pub.dev; cần xác nhận quyền phân phối. `LICENSE` và `homepage`/`author`
  trong podspec là placeholder; URL git trong README là placeholder.
- `_appendFaceLog`: ý nghĩa cột status (20/15) chưa xác định được từ tài liệu; giữ hành vi cũ.
- Chuỗi `errorMessage` cố định trong `VnptClient` / `startFullFlow` (ví dụ "Người dùng đã huỷ xác thực.") vẫn là tiếng Việt.
