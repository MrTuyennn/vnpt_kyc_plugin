import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/camera_frame_util.dart';

/// Preview camera phủ kín màn hình, không có dải trống.
///
/// - Mặc định: [BoxFit.cover] (màn quét CCCD; khung thẻ tính theo phép chiếu này).
/// - [ovalRegionWidthFitsScreen] (màn khuôn mặt): lớp trên vẽ vùng 3:4 giữa ảnh
///   rộng đúng bằng chiều ngang màn hình, y hệt khi camera chỉ nằm trong khung 3:4
///   (oval, vùng engine cắt không đổi). Phần ảnh thừa phía trên/dưới vùng 3:4 được
///   vẽ nối liền; nếu vẫn còn khe hở (màn quá dài) thì lớp cover bên dưới lấp.
class CameraBackdrop extends StatelessWidget {
  const CameraBackdrop({
    super.key,
    required this.controller,
    this.ovalRegionWidthFitsScreen = false,
  });

  final CameraController controller;
  final bool ovalRegionWidthFitsScreen;

  Widget _scaled(Size preview, double scale) => OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: preview.width * scale,
        maxHeight: preview.height * scale,
        child: SizedBox(
          width: preview.width * scale,
          height: preview.height * scale,
          child: CameraPreview(controller),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final preview = portraitPreviewSize(controller);
    return ClipRect(
      child: LayoutBuilder(builder: (context, constraints) {
        final screen = constraints.biggest;
        final cover = math.max(
          screen.width / preview.width,
          screen.height / preview.height,
        );
        if (!ovalRegionWidthFitsScreen) return _scaled(preview, cover);
        final exact = screen.width / ovalRegionInPreview(preview).width;
        if (exact >= cover) return _scaled(preview, exact);
        // Còn khe hở: làm mờ dần mép lớp chính vào lớp cover bên dưới để không
        // lộ đường biên (hai "box" trên/dưới).
        final layer = preview.height * exact;
        final top = (screen.height - layer) / 2 / screen.height;
        final bottom = 1 - top;
        final fade = layer * 0.15 / screen.height;
        return Stack(
          fit: StackFit.expand,
          children: [
            _scaled(preview, cover),
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Color(0x00FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: [top, top + fade, bottom - fade, bottom],
              ).createShader(rect),
              child: _scaled(preview, exact),
            ),
          ],
        );
      }),
    );
  }
}
