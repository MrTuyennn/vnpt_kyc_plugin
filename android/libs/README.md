# Binary SDK VNPT (Android)

| File | Nguồn | SHA-256 |
|------|-------|---------|
| `ekyc_sdk-release-v3.7.4.aar` | VNPT eKYC Android SDK v3.7.4 | `7af594eb856da71a8addb23378d1b154f43d1467c3845d0e1b821d636b248523` |

`android/build.gradle` khai báo `flatDir` trỏ vào thư mục này và `api(name: "ekyc_sdk-release-v3.7.4", ext: "aar")`.
Khi nâng cấp AAR: thay file, cập nhật tên trong `build.gradle` và SHA-256 ở bảng trên.

App host phải đặt `androidResources { noCompress += "bic" }` để engine mở được các model `.bic` (xem README gốc).
