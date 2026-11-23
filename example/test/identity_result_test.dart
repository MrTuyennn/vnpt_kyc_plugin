import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:ekyc_sdk2_example/api_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows OCR info without claiming failed liveness passed', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final result = verifyVnptIdentity(
      PipelineResult(
        success: true,
        ocrJson:
            '{"message":"IDG-00000000","object":{"id":"000000000000","name":"Người thử nghiệm"}}',
        liveness3dJson:
            '{"message":"IDG-00000000","object":{"liveness":false}}',
      ),
    );

    for (final width in [320.0, 375.0, 414.0, 768.0]) {
      tester.view.physicalSize = Size(width, 568);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(width),
          home: ApiResultScreen(result: result),
        ),
      );
      expect(find.text('Chưa hoàn tất xác thực'), findsOneWidget);
      expect(find.text('Xác thực thành công'), findsNothing);
      expect(find.text('Liveness đạt'), findsNothing);
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == 'Người thử nghiệm',
      );
      await tester.scrollUntilVisible(
        name,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(name, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
