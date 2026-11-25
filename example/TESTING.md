# Test demo SDK 2.0 (device)

## Luồng chính — dùng mỗi ngày

1. **Build** có `env.local.json`:
   ```bash
   flutter run --dart-define-from-file=env.local.json
   ```
2. Mở app là vào thẳng luồng xác thực (thoát luồng thì bấm **Bắt đầu xác thực** để mở lại).
3. Chụp **mặt trước** và **mặt sau** CCCD. Nút chụp bật khi camera nhận diện ảnh đạt chất lượng. Nếu ảnh chụp cuối không đạt, giữ thẻ trong khung và chụp lại.
4. Mở camera trước và thực hiện hai bước oval **xa → gần**. App tự chụp khi khung hình đạt yêu cầu.
5. Chọn **Tiếp tục** để gửi ảnh và dữ liệu 3D đến VNPT. Kết quả (JSON OCR hoặc mã lỗi) hiện dạng chữ trên màn home.

## Log

Lọc console: `EkycSDK`

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
