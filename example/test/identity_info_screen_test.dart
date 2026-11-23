import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:ekyc_sdk2_example/identity_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('displays OCR values for review', (tester) async {
    final result = PipelineResult(
      success: true,
      ocrJson: '{"object":{"name":"Nguyen Van A","id":"123456789"}}',
    );
    await tester.pumpWidget(MaterialApp(home: IdentityInfoScreen(result: result)));
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.text('123456789'), findsOneWidget);
  });
}
