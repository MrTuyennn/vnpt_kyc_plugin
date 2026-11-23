# Test demo SDK 2.0 (device)

## Luồng chính — dùng mỗi ngày

1. **Build** có `env.local.json`:
   ```bash
   flutter run --dart-define-from-file=env.local.json
   ```
2. Màn **home** → kiểm tra “Sẵn sàng gọi API”.
3. Chọn **Bắt đầu xác thực**, rồi chụp **mặt trước** và **mặt sau** CCCD. Nút chụp bật khi camera nhận diện ảnh đạt chất lượng. Nếu ảnh chụp cuối không đạt, giữ thẻ trong khung và chụp lại.
4. Mở camera trước và thực hiện hai bước oval **xa → gần**. App tự chụp khi khung hình đạt yêu cầu.
5. Chọn **Gửi và xem kết quả** để gửi ảnh và dữ liệu 3D đến VNPT. Màn kết quả hiện thông tin đọc từ CCCD cùng trạng thái khuôn mặt. Mục **Chi tiết kiểm tra** chứa mã lỗi và JSON phản hồi.

## Log

Lọc console: `EkycSDK`

## QA kỹ thuật (tùy chọn)

Home → **Công cụ QA** (ma trận T* cũ, L0/L1).

## Auth (401 / `invalid_token`)

**Header gửi lên (đúng cookbook VNPT):**

| Header | Giá trị trong `env.local.json` |
|--------|--------------------------------|
| `Authorization` | `Bearer eyJ…` **hoặc** chỉ `eyJ…` (app tự thêm `Bearer `) |
| `token-id` | `TOKEN_ID` |
| `token-key` | `TOKEN_KEY` |

Không gộp `TOKEN_ID` / `TOKEN_KEY` vào `ACCESS_TOKEN`. Không viết `Bearer Bearer …`.

Sau sửa `env.local.json` → **rebuild** (`flutter run --dart-define-from-file=env.local.json`), không hot reload.

Log Xcode/Logcat: `[EkycSDK/auth] … shape=bearer len=…` — nếu `empty` thì build-time token chưa vào app.

401 thường còn do: JWT hết hạn, bộ `token-id`/`token-key` không khớp access token, `CHALLENGE_CODE` sai so với cổng VNPT, `BASE_URL` khác môi trường cấp token.
