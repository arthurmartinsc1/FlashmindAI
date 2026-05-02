import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flashmind_mobile/app.dart';

void main() {
  testWidgets('renders the FlashMind app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlashMindApp()));

    expect(find.byType(FlashMindApp), findsOneWidget);
  });
}
