import 'package:ekyc_sdk2_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home shows start button', (tester) async {
    await tester.pumpWidget(const EkycSdk2ExampleApp());
    expect(find.text('Bắt đầu xác thực'), findsOneWidget);
  });
}
