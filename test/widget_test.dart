import 'package:flutter_test/flutter_test.dart';

import 'package:simak_mosa/main.dart';

void main() {
  testWidgets('App menampilkan layar login saat belum login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SimakMosaApp(hasSeenOnboarding: true));
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke SIMAK'), findsOneWidget);
  });
}
