# Changelog

## 1.0.0

Gộp SDK eKYC 2.0 (`ekyc_platform` + `ekyc_sdk` + `ekyc_ui`) thành một plugin duy nhất.

### Thêm
- `VnptEkyc.startFullFlow(context, config)`: API cấp cao chạy trọn luồng CCCD trước → sau → khuôn mặt → gửi VNPT.
- `VnptClient` (Dart, `package:http`): upload file, OCR, liveness 3D. Thay thế toàn bộ HTTP native.
- Pigeon `EkycDeviceApi.deviceInfo()` để Dart dựng `client_session`.
- `EkycConfig.macAddress` (mặc định `TEST1`, như trước).

### Thay đổi
- `EkycConfigStore` → `EkycConfig`.
- Credential VNPT không còn gửi xuống native; native chỉ nhận `NativeEngineConfig`
  (`jpegQuality`, `previewHeight`, `ocrToken`, `isAutoCropParam`).
- `EkycNativePipeline` bị xoá; `EkycCore.runFullIdentity*` gọi `VnptClient`.
- iOS: mã lỗi pipeline giờ theo Android (`UPLOAD` / `API` / `PIPELINE`, message "Bước: …\nLỗi: …")
  thay cho `UPLOAD_HTTP_<n>`.
- Android: bỏ phụ thuộc `okhttp`, `gson` (không còn dùng).
- Mã kết quả iOS map tường minh sang `MessageResult` (giống Android); giá trị enum iOS không có
  tương ứng (11–18, 31–35) trả `-1` thay vì raw value.

### Sửa lỗi
- Hint bắn 2 lần mỗi frame (stream + `EkycEngineEvents`): bỏ `EkycEngineEvents`, chỉ dùng giá trị trả về.
- Bỏ `static _eventsBound`.
- `processOvalFrame` chỉ gọi `faceSetOvalPhase` / `faceSetPreviewSize` khi giá trị đổi.
- `runFullIdentityFromPaths` kiểm tra file bất đồng bộ.
- Sửa `use_build_context_synchronously` trong example.
- iOS: thay symlink hỏng của `eKYCLib.xcframework` bằng bản thật.

### Xoá
- Kênh debug `vnpt_ekyc/diagnostics` (chỉ phục vụ log HTTP native, giờ log ở Dart).

### TODO
- `_appendFaceLog`: ý nghĩa cột status (20/15) chưa xác định được từ tài liệu; giữ hành vi cũ.
- `LICENSE`, `homepage`/`author` trong podspec là placeholder.
