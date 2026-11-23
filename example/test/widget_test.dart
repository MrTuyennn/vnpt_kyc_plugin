import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:ekyc_sdk2_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test hub loads', (tester) async {
    await tester.pumpWidget(EkycSdk2ExampleApp(core: EkycCore()));
    expect(find.textContaining('SDK 2.0'), findsOneWidget);
  });
}