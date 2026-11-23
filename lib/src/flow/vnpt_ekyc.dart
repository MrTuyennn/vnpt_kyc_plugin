import 'package:flutter/widgets.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_config.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_core.dart';
import 'package:vnpt_kyc_plugin/src/core/pipeline_models.dart';
import 'package:vnpt_kyc_plugin/src/flow/ekyc_flow_screen.dart';

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
}
