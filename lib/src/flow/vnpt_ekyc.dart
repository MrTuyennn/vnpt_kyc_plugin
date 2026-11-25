import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vnpt_kyc_plugin/src/api/ekyc_session_init.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_config.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_core.dart';
import 'package:vnpt_kyc_plugin/src/core/pipeline_models.dart';
import 'package:vnpt_kyc_plugin/src/flow/ekyc_flow_screen.dart';
import 'package:vnpt_kyc_plugin/src/flow/scan_results.dart';
import 'package:vnpt_kyc_plugin/src/ui/ekyc_card_scanner.dart';
import 'package:vnpt_kyc_plugin/src/ui/ekyc_oval_scanner.dart';

/// API cấp cao: chạy trọn luồng eKYC (CCCD mặt trước → mặt sau → khuôn mặt →
/// gửi VNPT) và trả về kết quả.
abstract final class VnptEkyc {
  /// Mở luồng xác thực. Hoàn tất khi:
  /// - xác thực thành công → `success == true`;
  /// - người dùng thoát → kết quả lỗi gần nhất, hoặc `errorCode == 'CANCELLED'`
  ///   nếu chưa gửi lần nào.
  ///
  /// [core] tuỳ chọn, mặc định tạo mới. Phiên được tạo và cấu hình bên trong.
  static Future<IdentityResult> startFullFlow(
    BuildContext context,
    EkycConfig config, {
    EkycCore? core,
  }) async {
    final navigator = Navigator.of(context);
    final ekycCore = core ?? EkycCore();
    await ekycCore.configure(config);
    await ekycCore.startSession();
    final result = await navigator.push<IdentityResult>(
      PageRouteBuilder<IdentityResult>(
        pageBuilder: (_, __, ___) =>
            EkycFlowScreen(core: ekycCore, config: config),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    return result ??
        IdentityResult(
          errorCode: 'CANCELLED',
          errorMessage: 'Người dùng đã huỷ xác thực.',
        );
  }

  /// Quét một mặt CCCD, trả file ảnh. Không gọi API; app tự upload/OCR.
  ///
  /// Trả `null` nếu người dùng thoát giữa chừng.
  static Future<CardScanResult?> scanCard(
    BuildContext context,
    EkycConfig config, {
    required VnptCardSide side,
  }) async {
    final navigator = Navigator.of(context);
    final core = EkycCore();
    await core.configure(config);
    final art = await core.startSession();
    final isFront = side == VnptCardSide.front;
    final ok = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => EkycCardScanner(core: core, isFront: isFront),
      ),
    );
    final full = isFront ? art.frontFull : art.backFull;
    final crop = isFront ? art.frontCrop : art.backCrop;
    if (ok != true || !await _hasFile(full)) {
      await _discard(art.rootDir);
      return null;
    }
    return CardScanResult(
      side: side,
      fullImagePath: full,
      cropImagePath: await _hasFile(crop) ? crop : full,
      cropParam: isFront ? art.cropParamFront : art.cropParamBack,
      sessionDir: art.rootDir.path,
    );
  }

  /// Quét khuôn mặt 3D (xa → gần), trả file ảnh và dữ liệu 3D. Không gọi API.
  ///
  /// Trả `null` nếu người dùng thoát giữa chừng.
  static Future<FaceScanResult?> scanFace(
    BuildContext context,
    EkycConfig config,
  ) async {
    final navigator = Navigator.of(context);
    final core = EkycCore();
    await core.configure(config);
    final art = await core.startSession();
    final ok = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => EkycOvalScanner(
          core: core,
          modeFaceOval: config.modeFaceOval,
          stableFrames: config.stableFaceFrames,
        ),
      ),
    );
    final complete = ok == true &&
        await _hasFile(art.farPreview) &&
        await _hasFile(art.nearPreview) &&
        await _hasFile(art.scan3d);
    if (!complete) {
      await _discard(art.rootDir);
      return null;
    }
    return FaceScanResult(
      farImagePath: art.farPreview,
      farCropPath: art.farCrop,
      nearImagePath: art.nearPreview,
      nearCropPath: art.nearCrop,
      scan3dPath: art.scan3d,
      faceLogPath: await _hasFile(art.faceLog) ? art.faceLog : null,
      sessionDir: art.rootDir.path,
    );
  }

  /// Thông tin thiết bị cho body `sessions/init` của backend (xem
  /// [EkycSessionInitRequest.toJson]). Lấy `deviceId` từ đây để truyền cho
  /// `EkycProxyClient.deviceId` cho nhất quán.
  static Future<EkycSessionInitRequest> sessionInitRequest({
    String sdkVersion = '3.7.4',
  }) async =>
      EkycSessionInitRequest.fromDevice(
        await EkycDeviceApi().deviceInfo(),
        sdkVersion: sdkVersion,
      );

  static Future<void> _discard(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Thư mục tạm; bỏ qua nếu không xoá được.
    }
  }

  static Future<bool> _hasFile(String path) async {
    final f = File(path);
    return await f.exists() && await f.length() > 0;
  }
}
