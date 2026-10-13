import 'package:flutter_test/flutter_test.dart';

import 'package:simak_mosa/main.dart';

void main() {
  testWidgets('App menampilkan layar login saat belum login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SimakMosaApp());
    await tester.pumpAndSettle();

    expect(find.text('SIMAK-MOSA'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
