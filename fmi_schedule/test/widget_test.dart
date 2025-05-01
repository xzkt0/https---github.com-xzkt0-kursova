import 'package:flutter_test/flutter_test.dart';

import 'package:fmi_schedule/main.dart';

void main() {
  testWidgets('Тест: екран вибору групи містить список', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FmiScheduleApp());

    expect(find.text('Оберіть свою групу'), findsOneWidget);
    expect(find.text('AB-12'), findsOneWidget);
  });
}
