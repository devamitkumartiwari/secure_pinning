import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secure_pinning_example/main.dart';

void main() {
  testWidgets('renders the pinning demo page', (WidgetTester tester) async {
    await tester.pumpWidget(const SecurePinningExampleApp());

    expect(find.text('secure_pinning example'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Raw HttpClient'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'package:http'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Dio'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Native probe (check())'),
      findsOneWidget,
    );

    expect(find.text('SPKI'), findsOneWidget);
    expect(find.text('Legacy leaf hash'), findsOneWidget);
    expect(find.text('Legacy CA hash'), findsOneWidget);

    await tester.tap(find.text('Legacy CA hash'));
    await tester.pump();
    expect(
      find.text('Acknowledged risk (required for legacy CA hash)'),
      findsOneWidget,
    );
  });
}
